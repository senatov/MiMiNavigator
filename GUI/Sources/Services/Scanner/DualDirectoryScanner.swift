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
        // Track currently watched paths to avoid restarting identical watchers
        private var leftWatchedPath: String?
        private var rightWatchedPath: String?

        // MARK: - Debounce: skip polling if FSEvents delivered changes recently
        private var lastFSEventsPatch: [PanelSide: Date] = [:]
        private let fsEventsDebounceInterval: TimeInterval = 120  // skip poll if FSEvents fired within 2 min

        // MARK: - Guard against overlapping scans (critical for 26K+ dirs)
        private var scanInProgress: [PanelSide: Bool] = [.left: false, .right: false]

        // MARK: - Scan task tracking for cancellation (navigation priority)
        private var activeScanTask: [PanelSide: Task<Void, Never>?] = [.left: nil, .right: nil]

        // Generation token to prevent stale scans from overriding newer navigation
        private var scanGeneration: [PanelSide: Int] = [.left: 0, .right: 0]

        // Prevent back‑to‑back full scans (navigation + timer firing)
        private var lastFullScan: [PanelSide: Date] = [:]
        private let scanCooldown: TimeInterval = 3

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
                let lURL = appState.leftURL
                let rURL = appState.rightURL
                await self.startFSEvents(for: .left, url: lURL)
                await self.startFSEvents(for: .right, url: rURL)
            }
        }

        // MARK: - Set directory for right panel
        func setRightDirectory(pathStr: String) {
        func setRightDirectory(pathStr: String) {
            guard pathStr.hasPrefix("/") else {
                log.error("\(#function) rejected non-absolute path: '\(pathStr)'")
                return
            }
            log.info("\(#function) '\(pathStr)'")
            let url = URL(fileURLWithPath: pathStr)
            // route through updatePath so TabManager + history stay in sync
            Task { @MainActor in appState.updatePath(url, for: .right) }
            startFSEvents(for: .right, url: url)
        }

        // MARK: - Set directory for left panel
        func setLeftDirectory(pathStr: String) {
            guard pathStr.hasPrefix("/") else {
                log.error("\(#function) rejected non-absolute path: '\(pathStr)'")
                return
            }
            log.info("\(#function) '\(pathStr)'")
            let url = URL(fileURLWithPath: pathStr)
            // route through updatePath so TabManager + history stay in sync
            Task { @MainActor in appState.updatePath(url, for: .left) }
            startFSEvents(for: .left, url: url)
        }

        // MARK: - FSEvents watcher setup
        /// Starts FSEventsDirectoryWatcher for a panel.
        /// Remote paths are skipped — FSEvents has no meaning for ftp:// / sftp://.
        /// async because showHiddenFiles is @MainActor-isolated (read via appState hop).
        private func startFSEvents(for side: PanelSide, url: URL) {
            guard !AppState.isRemotePath(url) else {
                log.debug("[FSEvents] Remote path — skip watcher: '\(url.path)' side=\(side)")
                stopFSEvents(for: side)
                return
            }
            // appState is @MainActor — read showHiddenFiles via async Task hop
            Task {
                let showHidden: Bool = await appState.showHiddenFilesSnapshot()
                launchFSEventsWatcher(for: side, path: url.path, showHiddenFiles: showHidden)
            }
        }

        private func launchFSEventsWatcher(for side: PanelSide, path: String, showHiddenFiles: Bool) {
            // Avoid restarting watcher if it already watches the same path
            switch side {
                case .left:
                    if leftWatchedPath == path { return }
                case .right:
                    if rightWatchedPath == path { return }
            }
            let watcher = FSEventsDirectoryWatcher { [weak self] patch in
                guard let self else { return }
                Task {
                    await self.applyPatch(patch, for: side)
                }
            }
            watcher.watch(path: path, showHiddenFiles: showHiddenFiles)
            switch side {
                case .left:
                    leftFSEvents?.stop()
                    leftFSEvents = watcher
                    leftWatchedPath = path
                case .right:
                    rightFSEvents?.stop()
                    rightFSEvents = watcher
                    rightWatchedPath = path
            }
            // Mark FSEvents as "active" so polling debounce kicks in for static dirs
            lastFSEventsPatch[side] = Date()
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
            // Dir-level FSEvents: full rescan needed (cannot determine removals incrementally)
            if patch.needsFullRescan {
                log.info("[FSEvents] needsFullRescan for \(side) panel")
                await refreshFiles(currSide: side)
                return
            }
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

        private static func binarySearchInsertIndex(_ list: [CustomFile], file: CustomFile, sortKey: SortKeysEnum, ascending: Bool) -> Int
        {
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
            }

            await refreshFiles(currSide: side)
        }

        // MARK: - Cancel running scan (used by navigation like "..")
        func cancelScan(for side: PanelSide) {
            if let task = activeScanTask[side] ?? nil {
                task.cancel()
            }
            activeScanTask[side] = nil
            scanInProgress[side] = false
            log.debug("[Scanner] Cancelled scan for \(side)")
        }

        // MARK: - Full refresh (used by timer safety net and explicit navigation)
        @Sendable
        func refreshFiles(currSide: PanelSide) async {
            if Task.isCancelled { return }
            // Guard: skip if a scan is already running for this panel
            guard scanInProgress[currSide] != true else {
                log.warning("[Scan] ⏭️ refreshFiles SKIPPED: scanInProgress=true for \(currSide)")
                return
            }

            // Guard: skip if a full scan happened very recently (navigation + timer double trigger)
            if let last = lastFullScan[currSide],
                Date().timeIntervalSince(last) < scanCooldown
            {
                log.warning("[Scan] ⏭️ refreshFiles SKIPPED: scanCooldown (\(String(format: "%.1f", Date().timeIntervalSince(last)))s < \(scanCooldown)s) for \(currSide)")
                return
            }
            // cancel any previous scan for this panel
            if let task = activeScanTask[currSide] ?? nil {
                task.cancel()
            }

            // Increment generation so older scans cannot override newer navigation
            scanGeneration[currSide, default: 0] += 1
            let generation = scanGeneration[currSide] ?? 0

            scanInProgress[currSide] = true
            log.debug("[Scan] Starting scan side=\(currSide)")
            activeScanTask[currSide] = Task { [weak self] in
                guard let self else { return }
                defer {
                    Task { await self.finishScan(for: currSide) }
                }

                await self.performRefreshFiles(currSide: currSide, generation: generation)
            }
            if let task = activeScanTask[currSide] ?? nil {
                await task.value
            }
            return
        }

        private func finishScan(for side: PanelSide) {
            scanInProgress[side] = false
            activeScanTask[side] = nil
            log.debug("[Scan] Finished scan side=\(side)")
        }

        private func performRefreshFiles(currSide: PanelSide, generation: Int) async {
            let scanStart = Date()
            let (url, showHidden, sortKey, sortAsc): (URL, Bool, SortKeysEnum, Bool) = await MainActor.run {
                let u = currSide == .left ? appState.leftURL : appState.rightURL
                let h = UserPreferences.shared.snapshot.showHiddenFiles
                return (u, h, appState.sortKey, appState.bSortAscending)
            }
            if AppState.isRemotePath(url) {
                await appState.refreshRemoteFiles(for: currSide)
                return
            }
            let originalURL = url

            let aliasResolvedURL: URL
            do {
                aliasResolvedURL = try URL(resolvingAliasFileAt: originalURL, options: [])
                if aliasResolvedURL.path != originalURL.path {
                    log.debug("[Scan] Alias resolved: '\(originalURL.path)' → '\(aliasResolvedURL.path)'")
                }
            } catch {
                aliasResolvedURL = originalURL
            }

            let resolvedURL = aliasResolvedURL.resolvingSymlinksInPath()
            if aliasResolvedURL.path != resolvedURL.path {
                log.debug("[Scan] Symlink resolved: '\(aliasResolvedURL.path)' → '\(resolvedURL.path)'")
            }

            let urlsToTry: [URL] = {
                var seen = Set<String>()
                var result: [URL] = []
                for candidate in [originalURL, aliasResolvedURL, resolvedURL] {
                    let path = candidate.path
                    if seen.insert(path).inserted {
                        result.append(candidate)
                    }
                }
                return result
            }()
            for (index, url) in urlsToTry.enumerated() {
                log.info("[Scan] Attempt \(index + 1)/\(urlsToTry.count): \(url.path)")
                // macOS-optimized: use URL resource values for directory validation
                // Fallback to FileManager for firmlinks (/tmp, /var, /etc) where
                // URL.resourceValues returns isDirectory==false despite being directories
                do {
                    let values = try url.resourceValues(forKeys: [.isDirectoryKey])
                    if values.isDirectory != true {
                        var isDir: ObjCBool = false
                        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                            log.debug("[Scan] firmlink directory confirmed via FileManager: \(url.path)")
                        } else {
                            log.error("[Scan] not a directory: \(url.path)")
                            continue
                        }
                    }
                } catch {
                    log.error("[Scan] cannot access path: \(url.path) error=\(error.localizedDescription)")
                    continue
                }
                do {
                    // Scan + sort in a single background task to reduce task overhead
                    let (_, sorted) = try await Task.detached(priority: .userInitiated) {
                        let scanned = try FileScanner.scan(url: url, showHiddenFiles: showHidden)
                        let sorted = FileSortingService.sort(scanned, by: sortKey, bDirection: sortAsc)
                        return (scanned, sorted)
                    }.value

                    // Progressive UI update for very large directories
                    if sorted.count > 150 {
                        let preview = Array(sorted.prefix(150))
                        await MainActor.run {
                            switch currSide {
                            case .left: appState.displayedLeftFiles = preview
                            case .right: appState.displayedRightFiles = preview
                            }
                        }
                    }

                    // Ignore stale scan results if a newer navigation started
                    if scanGeneration[currSide] != generation {
                        log.debug("[Scan] Ignoring stale scan result side=\(currSide) gen=\(generation)")
                        return
                    }

                    let duration = Date().timeIntervalSince(scanStart)
                    log.info("[Scan] Succeeded for \(url.path): \(sorted.count) items in \(String(format: "%.3f", duration))s")

                    lastFullScan[currSide] = Date()
                    await updateScannedFiles(sorted, for: currSide)
                    await updateFileList(panelSide: currSide, with: sorted)
                    return
                } catch let error as NSError {
                    if isPermissionDeniedError(error) {
                        log.debug("[Scan] Permission denied, skipping directory: \(url.path)")
                        // Do NOT retry, do NOT request access, just stop attempts.
                        break
                    }
                    log.error("[Scan] Attempt \(index + 1) failed: \(error.localizedDescription)")
                }
            }
            let duration = Date().timeIntervalSince(scanStart)
            log.debug("[Scan] Scan finished without access side=\(currSide) path='\(url.path)' in \(String(format: "%.3f", duration))s")
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
            log.info("[Permissions] Checking bookmarks for path='\(url.path)'")

            // 1. Try restoring all bookmarks first — maybe a parent bookmark covers this path
            let restored = await BookmarkStore.shared.restoreAll()
            if !restored.isEmpty {
                log.info("[Permissions] Restored \(restored.count) bookmark(s), retrying scan")
                do {
                    let showHidden = await MainActor.run { UserPreferences.shared.snapshot.showHiddenFiles }
                    let scanned = try FileScanner.scan(url: url, showHiddenFiles: showHidden)
                    log.info("[Permissions] Rescan succeeded: items=\(scanned.count) path='\(url.path)'")
                    await updateScannedFiles(scanned, for: side)
                    await updateFileList(panelSide: side, with: scanned)
                    return true
                } catch {
                    log.warning("[Permissions] Rescan after bookmark restore failed: \(error.localizedDescription)")
                }
            }

            // 2. No bookmark covers this path — fallback to Home instead of showing NSOpenPanel
            log.warning("[Permissions] No bookmark for path='\(url.path)', falling back to Home directory")
            let homeURL = URL(fileURLWithPath: NSHomeDirectory())
            await MainActor.run {
                log.debug(#function + ": setting Home as the current directory")
                appState.setURL(homeURL, for: side)
            }
            do {
                let showHidden = await MainActor.run { UserPreferences.shared.snapshot.showHiddenFiles }
                let scanned = try FileScanner.scan(url: homeURL, showHiddenFiles: showHidden)
                let sorted = FileSortingService.sort(
                    scanned, by: await MainActor.run { appState.sortKey }, bDirection: await MainActor.run { appState.bSortAscending })
                await updateScannedFiles(sorted, for: side)
                await updateFileList(panelSide: side, with: sorted)
                log.info("[Permissions] Fallback to Home succeeded: items=\(sorted.count)")
            } catch {
                log.error("[Permissions] Home directory scan failed: \(error)")
            }
            return false
        }

        // MARK: - Update displayed files (full replace — used by polling timer)
        // files arrive pre-sorted from Task.detached — no sort on MainActor
        @MainActor private var lastUpdateTime: [PanelSide: Date] = [:]
        @MainActor private var lastContentHashOnMain: [PanelSide: Int] = [:]

        @MainActor
        private func updateScannedFiles(_ incomingFiles: [CustomFile], for side: PanelSide) {
            // Ensure only a single parent ("..") entry exists
            var sortedFiles = incomingFiles
            var seenParent = false
            sortedFiles.removeAll { file in
                if file.isParentEntry {
                    if seenParent { return true }
                    seenParent = true
                }
                return false
            }
            // Ensure parent entry is the first row so keyboard navigation (↓, Enter) works correctly
            if let parentIndex = sortedFiles.firstIndex(where: { $0.isParentEntry }), parentIndex != 0 {
                let parent = sortedFiles.remove(at: parentIndex)
                sortedFiles.insert(parent, at: 0)
            }
            let now = Date()
            let isFirstUpdate = lastUpdateTime[side] == nil
            let sinceLastMs = isFirstUpdate ? "first update" : "\(Int(now.timeIntervalSince(lastUpdateTime[side]!) * 1000))ms since last"

            // Content hash: skip UI update if file list is identical (critical for 26K+ dirs)
            var hasher = Hasher()
            hasher.combine(sortedFiles.count)
            for f in sortedFiles { hasher.combine(f.id) }
            let newHash = hasher.finalize()
            if !isFirstUpdate && lastContentHashOnMain[side] == newHash {
                // Re-seed FSEvents debounce so we don't keep polling every 3s after 120s expiry
                Task { await self.resetFSEventsDebounce(for: side) }
                return
            }
            lastContentHashOnMain[side] = newHash

            lastUpdateTime[side] = now
            switch side {
                case .left: appState.displayedLeftFiles = sortedFiles
                case .right: appState.displayedRightFiles = sortedFiles
            }
            log.info("[Scanner] ✅ \(side) → \(sortedFiles.count) items (\(sinceLastMs))")
            // On first load: if the panel has no selection yet, pick the topmost file
            if isFirstUpdate {
                appState.ensureSelectionOnFocusedPanel()
                // Also seed selection on the non-focused panel — it gets ensureSelection on next focus
                switch side {
                    case .left where appState.selectedLeftFile == nil:
                        // Allow parent entry ("..") to be selectable via keyboard navigation
                        appState.selectedLeftFile = sortedFiles.first
                        log.debug("[Scanner] Auto-selected first left: \(sortedFiles.first?.nameStr ?? "-")")
                    case .right where appState.selectedRightFile == nil:
                        appState.selectedRightFile = sortedFiles.first
                        log.debug("[Scanner] Auto-selected first right: \(sortedFiles.first?.nameStr ?? "-")")
                    default: break
                }
            }
        }

        // MARK: - Re-seed FSEvents debounce (called when content unchanged after safety scan)
        func resetFSEventsDebounce(for side: PanelSide) {
            lastFSEventsPatch[side] = Date()
        }

        // MARK: - Clear scan cooldown (called by explicit navigation to avoid skipping)
        func clearCooldown(for side: PanelSide) {
            lastFullScan[side] = nil
            scanInProgress[side] = false
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
}
