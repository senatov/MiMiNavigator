// DualDirectoryScanner.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 11.12.24.
//  Copyright © 2024 Senatov. All rights reserved.
//  Description: Actor-based dual-panel directory scanner.
//    Local paths use FSEventsDirectoryWatcher for surgical per-file patch delivery.
//    Polling timer provides a safety net for edge cases (network mounts, slow FSEvents).
//    VNode DispatchSource removed — FSEvents is strictly superior for local directories.

import FileModelKit
import Foundation
import SwiftUI

// MARK: - Actor for concurrent directory scanning

actor DualDirectoryScanner {
    let appState: AppState
    var fileCache = FileCache.shared

    // MARK: - Polling timers (safety net — fire every refreshInterval seconds)
    private var leftTimer: DispatchSourceTimer?
    private var rightTimer: DispatchSourceTimer?

    // MARK: - FSEvents watchers (primary change detection — per-file events, no full scan)
    private var leftFSEvents: FSEventsDirectoryWatcher?
    private var rightFSEvents: FSEventsDirectoryWatcher?
    
    // MARK: - Debounce: skip polling if FSEvents delivered changes recently
    private var lastFSEventsPatch: [PanelSide: Date] = [:]
    private let fsEventsDebounceInterval: TimeInterval = 120  // skip poll if FSEvents fired within 2 min

    // MARK: - Guard against overlapping scans (critical for 26K+ dirs)
    private var scanInProgress: [PanelSide: Bool] = [.left: false, .right: false]

    /// Refresh interval from centralized constants (safety net only)
    private var refreshInterval: Int {
        Int(AppConstants.Scanning.refreshInterval)
    }

    init(appState: AppState) {
        self.appState = appState
    }

    // MARK: - Start monitoring both panels
    func startMonitoring() {
        setupTimer(for: .left)
        setupTimer(for: .right)
        if leftTimer == nil || rightTimer == nil {
            log.error("[DualDirectoryScanner] Failed to initialize directory timers")
        }
        Task { @MainActor in
            let lPath = appState.leftPath
            let rPath = appState.rightPath
            await self.startFSEvents(for: .left, path: lPath)
            await self.startFSEvents(for: .right, path: rPath)
        }
    }

    // MARK: - Set directory for right panel
    func setRightDirectory(pathStr: String) {
        log.info("[DualDirectoryScanner] setRightDirectory: '\(pathStr)'")
        Task { @MainActor in
            appState.rightPath = pathStr
        }
        startFSEvents(for: .right, path: pathStr)
    }

    // MARK: - Set directory for left panel
    func setLeftDirectory(pathStr: String) {
        log.info("[DualDirectoryScanner] setLeftDirectory: '\(pathStr)'")
        Task { @MainActor in
            appState.leftPath = pathStr
        }
        startFSEvents(for: .left, path: pathStr)
    }

    // MARK: - FSEvents watcher setup
    /// Starts FSEventsDirectoryWatcher for a panel.
    /// Remote paths are skipped — FSEvents has no meaning for ftp:// / sftp://.
    /// async because showHiddenFiles is @MainActor-isolated (read via appState hop).
    private func startFSEvents(for side: PanelSide, path: String) {
        guard !AppState.isRemotePath(path) else {
            log.debug("[FSEvents] Remote path — skip watcher: '\(path)' side=\(side)")
            stopFSEvents(for: side)
            return
        }
        // appState is @MainActor — read showHiddenFiles via async Task hop
        Task {
            let showHidden: Bool = await appState.showHiddenFilesSnapshot()
            launchFSEventsWatcher(for: side, path: path, showHiddenFiles: showHidden)
        }
    }

    private func launchFSEventsWatcher(for side: PanelSide, path: String, showHiddenFiles: Bool) {
        let watcher = FSEventsDirectoryWatcher { [weak self] patch in
            guard let self else { return }
            Task {
                await self.applyPatch(patch, for: side)
            }
        }
        watcher.watch(path: path, showHiddenFiles: showHiddenFiles)
        switch side {
            case .left: leftFSEvents = watcher
            case .right: rightFSEvents = watcher
        }
        log.info("[FSEvents] started for \(side) panel: '\(path)'")
    }

    private func stopFSEvents(for side: PanelSide) {
        switch side {
            case .left:
                leftFSEvents?.stop()
                leftFSEvents = nil
            case .right:
                rightFSEvents?.stop()
                rightFSEvents = nil
        }
    }

    // MARK: - Apply incremental patch from FSEvents
    private func applyPatch(_ patch: FSEventsDirectoryWatcher.DirectoryPatch, for side: PanelSide) async {
        lastFSEventsPatch[side] = Date()
        
        let childUpdates = patch.childCountUpdates
        let removedPaths = patch.removedPaths
        let addedOrModified = patch.addedOrModified
        
        let (current, sortKey, sortAsc): ([CustomFile], SortKeysEnum, Bool) = await MainActor.run {
            let files = side == .left ? appState.displayedLeftFiles : appState.displayedRightFiles
            return (files, appState.sortKey, appState.bSortAscending)
        }
        
        let totalChanges = addedOrModified.count + removedPaths.count
        let useIncremental = totalChanges <= 5 && totalChanges > 0
        
        var merged = current
        
        if !removedPaths.isEmpty {
            let removedSet = Set(removedPaths)
            merged.removeAll { removedSet.contains($0.pathStr) }
        }
        
        for updated in addedOrModified {
            if let idx = merged.firstIndex(where: { $0.pathStr == updated.pathStr }) {
                merged[idx] = updated
            } else if useIncremental {
                let insertIdx = Self.binarySearchInsertIndex(merged, file: updated, sortKey: sortKey, ascending: sortAsc)
                merged.insert(updated, at: insertIdx)
            } else {
                merged.append(updated)
            }
        }
        
        for (path, count) in childUpdates {
            if let idx = merged.firstIndex(where: { $0.pathStr == path }) {
                merged[idx].cachedChildCount = count
            }
        }
        
        if !useIncremental && totalChanges > 0 {
            merged = FileSortingService.sort(merged, by: sortKey, bDirection: sortAsc)
        }
        
        // Only log if something actually changed
        
        await MainActor.run {
            switch side {
                case .left: appState.displayedLeftFiles = merged
                case .right: appState.displayedRightFiles = merged
            }
        }
    }
    
    private static func binarySearchInsertIndex(_ list: [CustomFile], file: CustomFile, sortKey: SortKeysEnum, ascending: Bool) -> Int {
        var lo = 0
        var hi = list.count
        while lo < hi {
            let mid = (lo + hi) / 2
            let cmp = FileSortingService.compare(file, list[mid], by: sortKey, ascending: ascending)
            if cmp {
                hi = mid
            } else {
                lo = mid + 1
            }
        }
        return lo
    }

    private func setupTimer(for side: PanelSide) {
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
        // Start after first interval — avoids double scan at startup (refreshFiles already called explicitly)
        timer.schedule(deadline: .now() + .seconds(refreshInterval), repeating: .seconds(refreshInterval))
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            Task {
                await self.timerFired(for: side)
            }
        }
        timer.resume()
        switch side {
            case .left: leftTimer = timer
            case .right: rightTimer = timer
        }
    }
    
    // MARK: - Timer handler with smart skip
    private func timerFired(for side: PanelSide) async {
        // Check if FSEvents delivered changes recently — skip redundant poll
        if let lastPatch = lastFSEventsPatch[side] {
            let elapsed = Date().timeIntervalSince(lastPatch)
            if elapsed < fsEventsDebounceInterval {
                log.debug("[Scanner] skip poll \(side) — FSEvents active \(Int(elapsed))s ago")
                return
            }
        }
        
        // Check if FSEvents watcher is active for this panel
        let hasActiveWatcher: Bool
        switch side {
            case .left: hasActiveWatcher = leftFSEvents != nil
            case .right: hasActiveWatcher = rightFSEvents != nil
        }
        
        // For local paths with active FSEvents, only poll as safety net every 5 minutes
        // The 60s interval is now just for remote paths or when FSEvents failed
        if hasActiveWatcher {
            log.debug("[Scanner] poll \(side) — FSEvents active but no recent patches, running safety scan")
        }
        
        await refreshFiles(currSide: side)
    }

    // MARK: - Full refresh (used by timer safety net and explicit navigation)
    @Sendable
    func refreshFiles(currSide: PanelSide) async {
        // Guard: skip if a scan is already running for this panel
        guard scanInProgress[currSide] != true else {
            log.debug("[Scanner] skip refresh \(currSide) — scan already in progress")
            return
        }
        scanInProgress[currSide] = true
        defer { scanInProgress[currSide] = false }

        let (path, showHidden, sortKey, sortAsc): (String, Bool, SortKeysEnum, Bool) = await MainActor.run {
            let p = currSide == .left ? appState.leftPath : appState.rightPath
            let h = UserPreferences.shared.snapshot.showHiddenFiles
            return (p, h, appState.sortKey, appState.bSortAscending)
        }
        if AppState.isRemotePath(path) {
            await appState.refreshRemoteFiles(for: currSide)
            return
        }
        let originalURL = URL(fileURLWithPath: path)
        let resolvedURL = originalURL.resolvingSymlinksInPath()
        if originalURL.path != resolvedURL.path {
            log.debug("[Scan] Symlink resolved: '\(originalURL.path)' → '\(resolvedURL.path)'")
        }
        let urlsToTry =
            originalURL.path != resolvedURL.path
            ? [originalURL, resolvedURL]
            : [resolvedURL]
        for (index, url) in urlsToTry.enumerated() {
            log.info("[Scan] Attempt \(index + 1)/\(urlsToTry.count): \(url.path)")
            do {
                // Sort off MainActor — for 26k files this takes ~100ms
                let sorted = try await Task.detached(priority: .userInitiated) {
                    let scanned = try FileScanner.scan(url: url, showHiddenFiles: showHidden)
                    return FileSortingService.sort(scanned, by: sortKey, bDirection: sortAsc)
                }.value
                log.info("[Scan] Succeeded for \(url.path): \(sorted.count) items")
                await updateScannedFiles(sorted, for: currSide)
                await updateFileList(panelSide: currSide, with: sorted)
                return
            } catch let error as NSError {
                log.error("[Scan] Attempt \(index + 1) failed: \(error.localizedDescription)")
                if isPermissionDeniedError(error) {
                    log.warning("[Scan] Permission denied for \(url.path), requesting access...")
                    let granted = await requestAndRetryAccess(for: url, side: currSide)
                    if granted {
                        log.info("[Scan] Access granted, rescan succeeded for \(url.path)")
                        return
                    }
                    log.warning("[Scan] Access request denied for \(url.path)")
                }
            }
        }
        log.error("💀 ALL scan attempts failed for <<\(currSide)>> path: '\(path)'")
    }

    // MARK: - Permission helpers
    private func isPermissionDeniedError(_ error: NSError) -> Bool {
        if error.domain == NSCocoaErrorDomain && error.code == 257 { return true }
        if error.domain == NSPOSIXErrorDomain && error.code == 13 { return true }
        if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError {
            return isPermissionDeniedError(underlying)
        }
        return false
    }

    private func requestAndRetryAccess(for url: URL, side: PanelSide) async -> Bool {
        log.info("🔐 requestAndRetryAccess: checking existing bookmarks for \(url.path)")

        // 1. Try restoring all bookmarks first — maybe a parent bookmark covers this path
        let restored = await BookmarkStore.shared.restoreAll()
        if !restored.isEmpty {
            log.info("🔐 Re-restored \(restored.count) bookmarks, retrying scan")
            do {
                let showHidden = await MainActor.run { UserPreferences.shared.snapshot.showHiddenFiles }
                let scanned = try FileScanner.scan(url: url, showHiddenFiles: showHidden)
                log.info("✅ Rescan after bookmark restore: \(scanned.count) items from \(url.path)")
                await updateScannedFiles(scanned, for: side)
                await updateFileList(panelSide: side, with: scanned)
                return true
            } catch {
                log.warning("🔐 Rescan still failed after bookmark restore: \(error.localizedDescription)")
            }
        }

        // 2. No bookmark covers this path — fallback to Home instead of showing NSOpenPanel
        log.warning("🔐 No bookmark for \(url.path) — falling back to Home directory")
        let homeURL = URL(fileURLWithPath: NSHomeDirectory())
        await MainActor.run {
            switch side {
            case .left:  appState.leftPath = homeURL.path
            case .right: appState.rightPath = homeURL.path
            }
        }
        do {
            let showHidden = await MainActor.run { UserPreferences.shared.snapshot.showHiddenFiles }
            let scanned = try FileScanner.scan(url: homeURL, showHiddenFiles: showHidden)
            let sorted = FileSortingService.sort(scanned, by: await MainActor.run { appState.sortKey }, bDirection: await MainActor.run { appState.bSortAscending })
            await updateScannedFiles(sorted, for: side)
            await updateFileList(panelSide: side, with: sorted)
            log.info("✅ Fallback to Home succeeded: \(sorted.count) items")
        } catch {
            log.error("❌ Even Home dir scan failed: \(error)")
        }
        return false
    }

    // MARK: - Update displayed files (full replace — used by polling timer)
    // files arrive pre-sorted from Task.detached — no sort on MainActor
    @MainActor private var lastUpdateTime: [PanelSide: Date] = [:]
    @MainActor private var lastContentHashOnMain: [PanelSide: Int] = [:]

    @MainActor
    private func updateScannedFiles(_ sortedFiles: [CustomFile], for side: PanelSide) {
        let now = Date()
        let isFirstUpdate = lastUpdateTime[side] == nil
        let sinceLastMs = isFirstUpdate ? "first update" : "\(Int(now.timeIntervalSince(lastUpdateTime[side]!) * 1000))ms since last"

        // Content hash: skip UI update if file list is identical (critical for 26K+ dirs)
        var hasher = Hasher()
        hasher.combine(sortedFiles.count)
        for f in sortedFiles { hasher.combine(f.id) }
        let newHash = hasher.finalize()
        if !isFirstUpdate && lastContentHashOnMain[side] == newHash {
            log.debug("[Scanner] skip update \(side): \(sortedFiles.count) items unchanged (\(sinceLastMs))")
            return
        }
        lastContentHashOnMain[side] = newHash

        lastUpdateTime[side] = now
        switch side {
            case .left: appState.displayedLeftFiles = sortedFiles
            case .right: appState.displayedRightFiles = sortedFiles
        }
        log.debug("[Scanner] Full update \(side): \(sortedFiles.count) items (\(sinceLastMs))")
        // On first load: if the panel has no selection yet, pick the topmost file
        if isFirstUpdate {
            appState.ensureSelectionOnFocusedPanel()
            // Also seed selection on the non-focused panel — it gets ensureSelection on next focus
            switch side {
            case .left  where appState.selectedLeftFile == nil:
                appState.selectedLeftFile = sortedFiles.first
                log.debug("[Scanner] Auto-selected first left: \(sortedFiles.first?.nameStr ?? "-")")
            case .right where appState.selectedRightFile == nil:
                appState.selectedRightFile = sortedFiles.first
                log.debug("[Scanner] Auto-selected first right: \(sortedFiles.first?.nameStr ?? "-")")
            default: break
            }
        }
    }

    // MARK: - Reset timer for a panel
    func resetRefreshTimer(for side: PanelSide) {
        switch side {
            case .left:
                leftTimer?.cancel()
                leftTimer = nil
                setupTimer(for: .left)
            case .right:
                rightTimer?.cancel()
                rightTimer = nil
                setupTimer(for: .right)
        }
    }

    // MARK: - Stop all watchers
    func stopMonitoring() {
        leftTimer?.cancel()
        leftTimer = nil
        rightTimer?.cancel()
        rightTimer = nil
        stopFSEvents(for: .left)
        stopFSEvents(for: .right)
        log.info("[DualDirectoryScanner] stopMonitoring: all timers and FSEvents watchers stopped")
    }

    // MARK: - Update file list in storage
    @MainActor
    private func updateFileList(panelSide: PanelSide, with files: [CustomFile]) async {
        switch panelSide {
            case .left: await fileCache.updateLeftFiles(files)
            case .right: await fileCache.updateRightFiles(files)
        }
    }
}
