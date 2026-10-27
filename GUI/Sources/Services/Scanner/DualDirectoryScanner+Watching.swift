// DualDirectoryScanner+Watching.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 30.03.2026.
// Description: Watchers, timers and incremental FSEvents patch handling.

import FileModelKit
import Foundation

// MARK: - Scanner Patch State
struct ScannerPatchState {
    let files: [CustomFile]
    let sortKey: SortKeysEnum
    let sortAsc: Bool
}

extension DualDirectoryScanner {

    // MARK: - Active Watcher Check
    func hasActiveFSEventsWatcher(for side: FavPanelSide, path: String) -> Bool {
        switch side {
            case .left: return leftFSEvents != nil && leftWatchedPath == path
            case .right: return rightFSEvents != nil && rightWatchedPath == path
        }
    }

    // MARK: - FSEvents watcher setup
    /// Starts FSEventsDirectoryWatcher for a panel.
    /// Remote paths are skipped — FSEvents has no meaning for ftp:// / sftp://.
    /// async because showHiddenFiles is MainActor-isolated.
    func startFSEvents(for side: FavPanelSide, url: URL) {
        guard !AppState.isRemotePath(url) else {
            log.debug("[FSEvents] Remote path — skip watcher: '\(url.path)' side=\(side)")
            stopFSEvents(for: side)
            return
        }
        guard !AppState.isAppManagedNetworkMountPath(url) else {
            log.debug("[FSEvents] app-managed network mount — skip watcher: '\(url.path)' side=\(side)")
            stopFSEvents(for: side)
            return
        }
        if hasActiveFSEventsWatcher(for: side, path: url.path) {
            requestedWatchedPath[side] = url.path
            return
        }
        let requestID = UUID()
        requestedWatchedPath[side] = url.path
        watcherRequestID[side] = requestID
        Task {
            let showHidden = await appState.showHiddenFilesSnapshot()
            guard requestedWatchedPath[side] == url.path,
                watcherRequestID[side] == requestID
            else {
                log.debug("[FSEvents] stale watcher start ignored: '\(url.path)' side=\(side)")
                return
            }
            launchFSEventsWatcher(for: side, path: url.path, showHiddenFiles: showHidden, requestID: requestID)
        }
    }

    func launchFSEventsWatcher(for side: FavPanelSide, path: String, showHiddenFiles: Bool, requestID: UUID) {
        let watcher = FSEventsDirectoryWatcher { [weak self] patch in
            guard let self else { return }
            Task {
                await self.applyPatch(patch, for: side, watcherID: requestID)
            }
        }

        guard watcher.watch(path: path, showHiddenFiles: showHiddenFiles) else {
            log.error("[FSEvents] watcher start failed for \(side) panel: '\(path)'")
            stopFSEvents(for: side)
            return
        }

        switch side {
            case .left:
                leftFSEvents?.stop()
                leftFSEvents = watcher
                leftWatchedPath = path
                activeWatcherID[side] = requestID
            case .right:
                rightFSEvents?.stop()
                rightFSEvents = watcher
                rightWatchedPath = path
                activeWatcherID[side] = requestID
        }

        log.info("[FSEvents] started for \(side) panel: '\(path)'")
    }

    func stopFSEvents(for side: FavPanelSide) {
        requestedWatchedPath[side] = nil
        watcherRequestID[side] = nil
        activeWatcherID[side] = nil
        switch side {
            case .left:
                leftFSEvents?.stop()
                leftFSEvents = nil
                leftWatchedPath = nil
            case .right:
                rightFSEvents?.stop()
                rightFSEvents = nil
                rightWatchedPath = nil
        }
    }

    // MARK: - Incremental patch application

    func applyPatch(_ patch: FSEventsDirectoryWatcher.DirectoryPatch, for side: FavPanelSide, watcherID: UUID) async {
        guard isCurrentWatcherPatch(patch, for: side, watcherID: watcherID) else {
            log.debug("[FSEvents] stale patch ignored for \(side): '\(patch.watchedPath)'")
            return
        }
        lastFSEventsPatch[side] = Date()
        if batchMutationDepth > 0 {
            log.debug("[FSEvents] patch deferred during batch mutation for \(side)")
            return
        }
        if scanInProgress[side] == true {
            pendingRefreshAfterScan[side] = true
            log.debug("[FSEvents] refresh queued after active scan for \(side)")
            return
        }
        if patch.needsFullRescan {
            log.info("[FSEvents] needsFullRescan for \(side) panel")
            await DirectoryContentCache.shared.invalidate(patch.watchedPath)
            guard isCurrentWatcherPatch(patch, for: side, watcherID: watcherID) else { return }
            await refreshFiles(currSide: side, force: true)
            return
        }
        await applyIncrementalPatch(patch, for: side, watcherID: watcherID)
    }

    // MARK: - Current Watcher Patch
    private func isCurrentWatcherPatch(
        _ patch: FSEventsDirectoryWatcher.DirectoryPatch,
        for side: FavPanelSide,
        watcherID: UUID
    ) -> Bool {
        let activePath = side == .left ? leftWatchedPath : rightWatchedPath
        return activePath == patch.watchedPath
            && requestedWatchedPath[side] == patch.watchedPath
            && activeWatcherID[side] == watcherID
    }

    // MARK: - Apply Incremental Patch
    private func applyIncrementalPatch(
        _ patch: FSEventsDirectoryWatcher.DirectoryPatch,
        for side: FavPanelSide,
        watcherID: UUID
    ) async {
        let childUpdates = patch.childCountUpdates
        let removedPaths = patch.removedPaths
        let addedOrModified = patch.addedOrModified
        let state = await currentPatchState(for: side)
        guard isCurrentWatcherPatch(patch, for: side, watcherID: watcherID) else { return }
        let totalChanges = addedOrModified.count + removedPaths.count
        if totalChanges == 0 {
            applyChildCountUpdates(childUpdates, to: state.files)
            guard isCurrentWatcherPatch(patch, for: side, watcherID: watcherID) else { return }
            guard await publishPatchFiles(state.files, for: side, watchedPath: patch.watchedPath) else { return }
            let showHidden = await appState.showHiddenFilesSnapshot()
            guard isCurrentWatcherPatch(patch, for: side, watcherID: watcherID) else { return }
            await DirectoryContentCache.shared.store(
                path: patch.watchedPath,
                files: state.files,
                showHidden: showHidden
            )
            return
        }
        let useIncremental = totalChanges <= 5
        var merged = state.files
        if !removedPaths.isEmpty {
            let removedSet = Set(removedPaths)
            merged.removeAll { removedSet.contains($0.pathStr) }
        }
        mergeUpdatedFiles(
            into: &merged,
            updates: addedOrModified,
            useIncremental: useIncremental,
            sortKey: state.sortKey,
            sortAsc: state.sortAsc
        )
        applyChildCountUpdates(childUpdates, to: merged)
        if !useIncremental {
            merged = FileSortingService.sort(merged, by: state.sortKey, bDirection: state.sortAsc)
        }
        guard isCurrentWatcherPatch(patch, for: side, watcherID: watcherID) else { return }
        guard await publishPatchFiles(merged, for: side, watchedPath: patch.watchedPath) else { return }
        let showHidden = await appState.showHiddenFilesSnapshot()
        guard isCurrentWatcherPatch(patch, for: side, watcherID: watcherID) else { return }
        await DirectoryContentCache.shared.store(
            path: patch.watchedPath,
            files: merged,
            showHidden: showHidden
        )
    }

    @MainActor
    func currentPatchState(for side: FavPanelSide) -> ScannerPatchState {
        let files = side == .left ? appState.displayedLeftFiles : appState.displayedRightFiles
        return ScannerPatchState(
            files: files,
            sortKey: appState.sortKey,
            sortAsc: appState.bSortAscending
        )
    }

    @MainActor
    func publishPatchFiles(_ files: [CustomFile], for side: FavPanelSide, watchedPath: String) -> Bool {
        guard PathUtils.areEqual(appState.path(for: side), watchedPath) else {
            log.debug("[FSEvents] patch discarded after panel navigation: '\(watchedPath)'")
            return false
        }
        publishDisplayedFiles(files, for: side)
        return true
    }

    func mergeUpdatedFiles(
        into files: inout [CustomFile],
        updates: [CustomFile],
        useIncremental: Bool,
        sortKey: SortKeysEnum,
        sortAsc: Bool
    ) {
        for updated in updates {
            if let index = files.firstIndex(where: { $0.pathStr == updated.pathStr }) {
                files.remove(at: index)
            }
            if useIncremental {
                let insertIndex = Self.binarySearchInsertIndex(
                    files,
                    file: updated,
                    sortKey: sortKey,
                    ascending: sortAsc
                )
                files.insert(updated, at: insertIndex)
            } else {
                files.append(updated)
            }
        }
    }

    func applyChildCountUpdates(_ childUpdates: [String: Int], to files: [CustomFile]) {
        for (path, count) in childUpdates {
            if let index = files.firstIndex(where: { $0.pathStr == path }) {
                files[index].cachedChildCount = count
            }
        }
    }

    static func binarySearchInsertIndex(
        _ list: [CustomFile],
        file: CustomFile,
        sortKey: SortKeysEnum,
        ascending: Bool
    ) -> Int {
        var low = 0
        var high = list.count

        while low < high {
            let mid = (low + high) / 2
            let shouldComeBefore = FileSortingService.comesBefore(
                file,
                list[mid],
                by: sortKey,
                ascending: ascending
            )

            if shouldComeBefore {
                high = mid
            } else {
                low = mid + 1
            }
        }
        return low
    }

    // MARK: - Timer setup

    func setupTimer(for side: FavPanelSide) {
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
        let interval = max(refreshInterval, Int(fallbackScanInterval))

        timer.schedule(
            deadline: .now() + .seconds(interval),
            repeating: .seconds(interval),
            leeway: .seconds(15)
        )

        timer.setEventHandler { [weak self] in
            guard let self else { return }
            Task {
                await self.timerFired(for: side)
            }
        }
        timer.resume()
        switch side {
            case .left:
                leftTimer = timer
            case .right:
                rightTimer = timer
        }
    }

    func timerFired(for side: FavPanelSide) async {
        let isTerminating = await MainActor.run { appState.isTerminating }
        if isTerminating { return }
        let isRemote = await isRemotePanelPath(for: side)
        if isRemote { return }
        if shouldSkipTimerRefresh(for: side) {
            return
        }
        await refreshFiles(currSide: side)
    }

    @MainActor
    func isRemotePanelPath(for side: FavPanelSide) -> Bool {
        let url = side == .left ? appState.leftURL : appState.rightURL
        return AppState.isRemotePath(url)
    }

    func shouldSkipTimerRefresh(for side: FavPanelSide) -> Bool {
        let watchedPath = side == .left ? leftWatchedPath : rightWatchedPath
        guard let lastFullScan = lastFullScan[side] else { return false }
        let elapsed = Date().timeIntervalSince(lastFullScan)
        let fallbackInterval: TimeInterval
        if let watchedPath, hasActiveFSEventsWatcher(for: side, path: watchedPath) {
            fallbackInterval = watcherIntegrityScanInterval
        } else {
            fallbackInterval = fallbackScanInterval
        }
        return elapsed < max(fallbackInterval, adaptiveCooldown(for: side))
    }

    // MARK: - Timer / watcher maintenance

    func resetRefreshTimer(for side: FavPanelSide) {
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

    func restartFSEventsWatchers() async {
        let panelURLs = await currentPanelURLs()
        stopFSEvents(for: .left)
        stopFSEvents(for: .right)
        startFSEvents(for: .left, url: panelURLs.left)
        startFSEvents(for: .right, url: panelURLs.right)

        log.info("[FSEvents] watchers restarted after hidden files toggle")
    }

    @MainActor
    func currentPanelURLs() -> (left: URL, right: URL) {
        (appState.leftURL, appState.rightURL)
    }
}
