// DualDirectoryScanner+Refresh.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 30.03.2026.
// Description: Full refresh flow, scan lifecycle, URL resolution and local scan pipeline.

import FileModelKit
import Foundation

// MARK: - Scanner Panel State
struct ScannerPanelState {
    let url: URL
    let showHidden: Bool
    let sortKey: SortKeysEnum
    let sortAsc: Bool
}

// MARK: - Scan Attempt Context
struct ScanAttemptContext {
    let side: FavPanelSide
    let generation: Int
    let showHidden: Bool
    let sortKey: SortKeysEnum
    let sortAsc: Bool
    let scanStart: Date
}

// MARK: - Scan Attempt Result
enum ScanAttemptResult: Equatable {
    case continueScanning
    case stop
}

extension DualDirectoryScanner {

    // MARK: - Refresh guards

    func canStartRefresh(for side: FavPanelSide, force: Bool) -> Bool {
        if scanInProgress[side] == true && !force {
            log.debug("[Scan] refreshFiles skipped: scanInProgress=true for \(side)")
            return false
        }

        if !force, consumeRecentFSEventsSignal(for: side) {
            return true
        }

        if !force, let last = lastFullScan[side] {
            let elapsed = Date().timeIntervalSince(last)
            let effectiveCooldown = adaptiveCooldown(for: side)
            if elapsed < effectiveCooldown {
                let elapsedText = String(format: "%.1f", elapsed)
                log.debug("[Scan] refreshFiles skipped: scanCooldown (\(elapsedText)s < \(effectiveCooldown)s) for \(side) without recent FSEvents signal")
                return false
            }
        }

        return true
    }

    /// Adaptive cooldown: big slow dirs get longer cooldown.
    /// Base = 3s, but if last scan took >5s, cooldown = min(scanDuration * 3, 120s).
    /// Prevents re-scanning 19k-file Outlook dirs every 3 seconds.
    func adaptiveCooldown(for side: FavPanelSide) -> TimeInterval {
        guard let lastDuration = lastScanDuration[side], lastDuration > 5 else {
            return scanCooldown
        }
        return min(lastDuration * 3, 120)
    }

    private func consumeRecentFSEventsSignal(for side: FavPanelSide) -> Bool {
        guard let lastPatch = lastFSEventsPatch[side] else { return false }

        let elapsed = Date().timeIntervalSince(lastPatch)
        guard elapsed < scanCooldown else {
            lastFSEventsPatch[side] = nil
            return false
        }

        lastFSEventsPatch[side] = nil
        let elapsedText = String(format: "%.1f", elapsed)
        log.info("[Scan] consuming recent FSEvents signal (\n            \(elapsedText)s) and bypassing cooldown for \(side)")
        return true
    }

    // MARK: - Scan lifecycle

    func refreshFiles(currSide: FavPanelSide, force: Bool = false) async {
        if Task.isCancelled { return }
        let isTerminating = await MainActor.run { appState.isTerminating }
        guard !isTerminating else {
            log.info("[Scan] refreshFiles skipped: app is terminating for \(currSide)")
            return
        }
        guard canStartRefresh(for: currSide, force: force) else { return }

        if force {
            log.debug("[Scan] forced refresh requested (file op / navigation), bypassing cooldown and scan guards for \(currSide)")
        }

        if let existingTask = activeScanTask[currSide] {
            existingTask.cancel()
            activeScanTask.removeValue(forKey: currSide)
        }

        scanGeneration[currSide, default: 0] += 1
        let generation = scanGeneration[currSide] ?? 0

        scanInProgress[currSide] = true
        log.debug("[Scan] Starting scan side=\(currSide) gen=\(generation)")

        let task = Task { [weak self] in
            guard let self else { return }
            await self.performRefreshFiles(currSide: currSide, generation: generation)
        }

        activeScanTask[currSide] = task
        await task.value
        await finishScan(for: currSide, expectedGeneration: generation)
    }

    func finishScan(for side: FavPanelSide, expectedGeneration: Int) async {
        let currentGeneration = scanGeneration[side] ?? 0
        guard currentGeneration == expectedGeneration else {
            log.debug(
                "[Scan] finish ignored for stale generation side=\(side) expected=\(expectedGeneration) current=\(currentGeneration)"
            )
            return
        }

        scanInProgress[side] = false
        activeScanTask.removeValue(forKey: side)
        log.debug("[Scan] Finished scan side=\(side) gen=\(expectedGeneration) active=false")
        guard pendingRefreshAfterScan[side] == true else { return }
        pendingRefreshAfterScan[side] = false
        log.info("[FSEvents] running queued refresh after scan for \(side)")
        await refreshFiles(currSide: side, force: true)
    }

    func cancelScan(for side: FavPanelSide) {
        if let task = activeScanTask[side] {
            task.cancel()
            activeScanTask.removeValue(forKey: side)
        }

        scanInProgress[side] = false
        log.debug("[Scanner] Cancelled scan for \(side)")
    }

    func clearCooldown(for side: FavPanelSide) {
        lastFullScan[side] = nil
        lastScanDuration[side] = nil
        scanInProgress[side] = false
    }

    func forceRefreshAfterFileOp(side: FavPanelSide) async {
        log.debug("[Scan] forceRefreshAfterFileOp triggered for \(side)")

        cancelScan(for: side)
        lastFullScan[side] = nil

        let path = await currentPanelPathOnMain(for: side)
        await DirectoryContentCache.shared.invalidate(path)
        await refreshFiles(currSide: side, force: true)
    }

    func isCurrentGeneration(_ generation: Int, for side: FavPanelSide) -> Bool {
        scanGeneration[side] == generation
    }

    // MARK: - Panel State Helpers

    // MARK: - URL / panel state helpers

    func isRemoteURL(_ url: URL) -> Bool {
        AppState.isRemotePath(url)
    }

    // MARK: - Current Panel State
    @MainActor
    func currentPanelState(for side: FavPanelSide) -> ScannerPanelState {
        let panelURL = side == .left ? appState.leftURL : appState.rightURL
        let hidden = UserPreferences.shared.snapshot.showHiddenFiles
        return ScannerPanelState(
            url: panelURL,
            showHidden: hidden,
            sortKey: appState.sortKey,
            sortAsc: appState.bSortAscending
        )
    }

    @MainActor
    func currentPanelPathOnMain(for side: FavPanelSide) -> String {
        switch side {
        case .left:
            return appState.leftURL.path
        case .right:
            return appState.rightURL.path
        }
    }

    func resolvedCandidateURLs(for originalURL: URL) -> [URL] {
        let aliasResolvedURL: URL

        do {
            aliasResolvedURL = try URL(resolvingAliasFileAt: originalURL, options: [])
            if aliasResolvedURL.path != originalURL.path {
                log.debug("[Scan] Alias resolved: '\(originalURL.path)' → '\(aliasResolvedURL.path)'")
            }
        } catch {
            aliasResolvedURL = originalURL
        }

        let symlinkResolvedURL = aliasResolvedURL.resolvingSymlinksInPath()
        if aliasResolvedURL.path != symlinkResolvedURL.path {
            log.debug("[Scan] Symlink resolved: '\(aliasResolvedURL.path)' → '\(symlinkResolvedURL.path)'")
        }

        var seen = Set<String>()
        var candidates: [URL] = []

        for candidate in [originalURL, aliasResolvedURL, symlinkResolvedURL]
        where seen.insert(candidate.path).inserted {
            candidates.append(candidate)
        }

        return candidates
    }

    func validateDirectoryURL(_ url: URL) -> Bool {
        if AppState.isAppManagedNetworkMountPath(url),
           let mountPointURL = AppState.appManagedMountPointURL(for: url),
           !AppState.isAppManagedNetworkMountPoint(url),
           !SMBFileProvider.isMounted(at: mountPointURL)
        {
            log.warning("[Scan] app-managed network mount is stale: \(mountPointURL.path)")
            return false
        }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            log.warning("[Scan] path no longer exists: \(url.path)")
            return false
        }
        guard isDirectory.boolValue else {
            log.debug("[Scan] skipping non-directory path: \(url.path)")
            return false
        }
        do {
            let values = try url.resourceValues(forKeys: [.isDirectoryKey])
            if values.isDirectory == true {
                return true
            }
            log.debug("[Scan] firmlink directory confirmed via FileManager: \(url.path)")
            return true
        } catch {
            log.error("[Scan] cannot access path: \(url.path) error=\(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Main scan flow

    func performRefreshFiles(currSide: FavPanelSide, generation: Int) async {
        let scanStart = Date()
        let panelState = await MainActor.run { currentPanelState(for: currSide) }
        let isTerminatingAtStart = await MainActor.run { appState.isTerminating }
        guard !isTerminatingAtStart else {
            log.info("[Scan] performRefreshFiles skipped before scan: app is terminating for \(currSide)")
            return
        }
        let originalURL = panelState.url
        let showHidden = panelState.showHidden
        let sortKey = panelState.sortKey
        let sortAsc = panelState.sortAsc
        let recoveryContext = ScanRecoveryContext(
            side: currSide,
            generation: generation,
            showHidden: showHidden,
            sortKey: sortKey,
            sortAsc: sortAsc
        )
        if await recoverMissingDirectoryIfNeeded(originalURL, context: recoveryContext) {
            return
        }

        if isRemoteURL(originalURL) {
            log.debug("[Scan] routing to remote refresh side=\(currSide) gen=\(generation)")
            await appState.refreshRemoteFiles(for: currSide)
            return
        }

        let context = ScanAttemptContext(
            side: currSide,
            generation: generation,
            showHidden: showHidden,
            sortKey: sortKey,
            sortAsc: sortAsc,
            scanStart: scanStart
        )
        await performLocalScanAttempts(
            resolvedCandidateURLs(for: originalURL),
            originalURL: originalURL,
            context: context
        )
    }
}
