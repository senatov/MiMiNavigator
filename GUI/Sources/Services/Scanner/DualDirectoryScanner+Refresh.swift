// DualDirectoryScanner+Refresh.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 30.03.2026.
// Description: Full refresh flow, scan lifecycle, URL resolution and local scan pipeline.

import FileModelKit
import Foundation

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
            if elapsed < scanCooldown {
                let elapsedText = String(format: "%.1f", elapsed)
                log.debug("[Scan] refreshFiles skipped: scanCooldown (\(elapsedText)s < \(scanCooldown)s) for \(side) without recent FSEvents signal")
                return false
            }
        }

        return true
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
        finishScan(for: currSide, expectedGeneration: generation)
    }

    func finishScan(for side: FavPanelSide, expectedGeneration: Int) {
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

    @MainActor
    func currentPanelState(for side: FavPanelSide) -> (url: URL, showHidden: Bool, sortKey: SortKeysEnum, sortAsc: Bool) {
        let panelURL = side == .left ? appState.leftURL : appState.rightURL
        let hidden = UserPreferences.shared.snapshot.showHiddenFiles
        return (panelURL, hidden, appState.sortKey, appState.bSortAscending)
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

        for candidate in [originalURL, aliasResolvedURL, symlinkResolvedURL] {
            if seen.insert(candidate.path).inserted {
                candidates.append(candidate)
            }
        }

        return candidates
    }

    func validateDirectoryURL(_ url: URL) -> Bool {
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
        if await recoverMissingDirectoryIfNeeded(originalURL, side: currSide, generation: generation, showHidden: showHidden, sortKey: sortKey, sortAsc: sortAsc) {
            return
        }

        if isRemoteURL(originalURL) {
            log.debug("[Scan] routing to remote refresh side=\(currSide) gen=\(generation)")
            await appState.refreshRemoteFiles(for: currSide)
            return
        }

        let urlsToTry = resolvedCandidateURLs(for: originalURL)

        for (index, url) in urlsToTry.enumerated() {
            log.info("[Scan] Attempt \(index + 1)/\(urlsToTry.count): \(url.path)")

            guard validateDirectoryURL(url) else {
                continue
            }

            do {
                let attemptStart = Date()
                let sorted = try await scanAndSortDirectory(
                    at: url,
                    showHidden: showHidden,
                    sortKey: sortKey,
                    sortAsc: sortAsc
                )
                let scanSortDuration = Date().timeIntervalSince(attemptStart)

                if !isCurrentGeneration(generation, for: currSide) {
                    let currentGeneration = scanGeneration[currSide] ?? -1
                    log.debug("[Scan] Ignoring stale scan result side=\(currSide) gen=\(generation) current=\(currentGeneration)")
                    return
                }

                if sorted.count > progressivePreviewThreshold {
                    let preview = Array(sorted.prefix(progressivePreviewThreshold))
                    await MainActor.run {
                        applyPreviewFiles(preview, for: currSide)
                    }
                }

                if !isCurrentGeneration(generation, for: currSide) {
                    let currentGeneration = scanGeneration[currSide] ?? -1
                    log.debug(
                        "[Scan] Ignoring post-preview stale result side=\(currSide) gen=\(generation) current=\(currentGeneration)"
                    )
                    return
                }

                let duration = Date().timeIntervalSince(scanStart)
                let durationText = String(format: "%.3f", duration)
                let scanSortText = String(format: "%.3f", scanSortDuration)
                log.info("[Scan] scan/sort succeeded for \(url.path): \(sorted.count) items gen=\(generation) scanSort=\(scanSortText)s total=\(durationText)s")

                let isTerminatingBeforePublish = await MainActor.run { appState.isTerminating }
                guard !isTerminatingBeforePublish else {
                    log.info("[Scan] publish skipped: app is terminating for \(currSide) gen=\(generation)")
                    return
                }

                let publishStart = Date()
                lastFullScan[currSide] = Date()
                await DirectoryContentCache.shared.store(path: url.path, files: sorted, showHidden: showHidden)
                await publishSuccessfulScan(sorted, scannedPath: url.path, for: currSide)
                let publishDuration = Date().timeIntervalSince(publishStart)
                logSlowScanIfNeeded(
                    path: url.path,
                    side: currSide,
                    generation: generation,
                    itemCount: sorted.count,
                    scanSortDuration: scanSortDuration,
                    publishDuration: publishDuration,
                    totalDuration: Date().timeIntervalSince(scanStart)
                )
                return
            } catch let error as NSError {
                if isPermissionDeniedError(error) {
                    log.debug("[Scan] Permission denied, trying bookmark recovery for: \(url.path)")
                    let recovered = await requestAndRetryAccess(for: url, side: currSide)
                    if recovered {
                        return
                    }
                    break
                }

                log.error("[Scan] Attempt \(index + 1) failed: \(error.localizedDescription)")
            }
        }

        let duration = Date().timeIntervalSince(scanStart)
        let durationText = String(format: "%.3f", duration)
        log.debug(
            "[Scan] Scan finished without access side=\(currSide) path='\(originalURL.path)' gen=\(generation) in \(durationText)s")
    }

    func scanAndSortDirectory(
        at url: URL,
        showHidden: Bool,
        sortKey: SortKeysEnum,
        sortAsc: Bool
    ) async throws -> [CustomFile] {
        try await Task.detached(priority: .userInitiated) {
            let scanned = try FileScanner.scan(url: url, showHiddenFiles: showHidden)
            return FileSortingService.sort(scanned, by: sortKey, bDirection: sortAsc)
        }
        .value
    }

    // MARK: - Missing Directory Recovery
    func recoverMissingDirectoryIfNeeded(
        _ url: URL,
        side: FavPanelSide,
        generation: Int,
        showHidden: Bool,
        sortKey: SortKeysEnum,
        sortAsc: Bool
    ) async -> Bool {
        guard url.isFileURL, !AppState.isExistingDirectory(url.path) else { return false }
        guard let fallbackURL = nearestExistingReadableDirectory(from: url), fallbackURL.path != url.path else { return false }
        log.warning("[Scan] current directory disappeared side=\(side) path='\(url.path)' fallback='\(fallbackURL.path)'")
        await MainActor.run {
            appState.updatePath(fallbackURL, for: side)
        }
        startFSEvents(for: side, url: fallbackURL)
        do {
            let sorted = try await scanAndSortDirectory(at: fallbackURL, showHidden: showHidden, sortKey: sortKey, sortAsc: sortAsc)
            guard isCurrentGeneration(generation, for: side) else { return true }
            lastFullScan[side] = Date()
            await DirectoryContentCache.shared.store(path: fallbackURL.path, files: sorted, showHidden: showHidden)
            await publishSuccessfulScan(sorted, scannedPath: fallbackURL.path, for: side)
        } catch {
            log.error("[Scan] fallback scan failed side=\(side) path='\(fallbackURL.path)' error=\(error.localizedDescription)")
        }
        return true
    }

    // MARK: - Nearest Existing Readable Directory
    func nearestExistingReadableDirectory(from url: URL) -> URL? {
        var candidate = url.deletingLastPathComponent()
        while candidate.path != "/" {
            if AppState.isReadableDirectory(candidate.path) {
                return candidate
            }
            let parent = candidate.deletingLastPathComponent()
            if parent.path == candidate.path { break }
            candidate = parent
        }
        return AppState.isReadableDirectory("/") ? URL(fileURLWithPath: "/") : nil
    }

    // MARK: - Slow Scan Diagnostics
    func logSlowScanIfNeeded(
        path: String,
        side: FavPanelSide,
        generation: Int,
        itemCount: Int,
        scanSortDuration: TimeInterval,
        publishDuration: TimeInterval,
        totalDuration: TimeInterval
    ) {
        guard totalDuration >= 2 || scanSortDuration >= 2 || publishDuration >= 1 else { return }
        let scanSortText = String(format: "%.3f", scanSortDuration)
        let publishText = String(format: "%.3f", publishDuration)
        let totalText = String(format: "%.3f", totalDuration)
        log.warning("[Scan] slow refresh side=\(side) gen=\(generation) path='\(path)' items=\(itemCount) scanSort=\(scanSortText)s publish=\(publishText)s total=\(totalText)s")
    }

    // MARK: - Watcher Signals

    func resetFSEventsDebounce(for side: FavPanelSide) {
        lastFSEventsPatch[side] = Date()
    }
}
