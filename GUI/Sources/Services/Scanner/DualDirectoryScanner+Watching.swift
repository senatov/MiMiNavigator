// DualDirectoryScanner+Watching.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 30.03.2026.
// Description: Watchers, timers and incremental FSEvents patch handling.

import FileModelKit
import Foundation

extension DualDirectoryScanner {

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
        Task {
            let showHidden = await appState.showHiddenFilesSnapshot()
            launchFSEventsWatcher(for: side, path: url.path, showHiddenFiles: showHidden)
        }
    }

    func launchFSEventsWatcher(for side: FavPanelSide, path: String, showHiddenFiles: Bool) {
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

        lastFSEventsPatch[side] = Date()
        log.info("[FSEvents] started for \(side) panel: '\(path)'")
    }

    func stopFSEvents(for side: FavPanelSide) {
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

    func applyPatch(_ patch: FSEventsDirectoryWatcher.DirectoryPatch, for side: FavPanelSide) async {
        lastFSEventsPatch[side] = Date()
        if patch.needsFullRescan {
            log.info("[FSEvents] needsFullRescan for \(side) panel")
            await refreshFiles(currSide: side)
            return
        }
        let childUpdates = patch.childCountUpdates
        let removedPaths = patch.removedPaths
        let addedOrModified = patch.addedOrModified
        let state = await currentPatchState(for: side)
        let totalChanges = addedOrModified.count + removedPaths.count
        // childCount-only patches: apply silently w/o triggering SwiftUI rebuild
        if totalChanges == 0 {
            if childUpdates.isEmpty { return }
            // CustomFile is @Observable class — mutate in-place, SwiftUI picks up
            // changes via observation. No publishDisplayedFiles needed.
            let files = state.files
            for (path, count) in childUpdates {
                if let idx = files.firstIndex(where: { $0.pathStr == path }),
                   files[idx].cachedChildCount != count {
                    files[idx].cachedChildCount = count
                }
            }
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
        applyChildCountUpdates(childUpdates, to: &merged)
        if !useIncremental {
            merged = FileSortingService.sort(merged, by: state.sortKey, bDirection: state.sortAsc)
        }
        await publishDisplayedFiles(merged, for: side)
    }

    @MainActor
    func currentPatchState(for side: FavPanelSide) -> (files: [CustomFile], sortKey: SortKeysEnum, sortAsc: Bool) {
        let files = side == .left ? appState.displayedLeftFiles : appState.displayedRightFiles
        return (files, appState.sortKey, appState.bSortAscending)
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
                files[index] = updated
                continue
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

    func applyChildCountUpdates(_ childUpdates: [String: Int], to files: inout [CustomFile]) {
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
            let shouldComeBefore = FileSortingService.compare(file, list[mid], by: sortKey, ascending: ascending)

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

        timer.schedule(
            deadline: .now() + .seconds(refreshInterval),
            repeating: .seconds(refreshInterval)
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
        guard let lastPatch = lastFSEventsPatch[side] else {
            return false
        }

        let elapsed = Date().timeIntervalSince(lastPatch)
        return elapsed < fsEventsDebounceInterval
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

        leftWatchedPath = nil
        rightWatchedPath = nil

        startFSEvents(for: .left, url: panelURLs.left)
        startFSEvents(for: .right, url: panelURLs.right)

        log.info("[FSEvents] watchers restarted after hidden files toggle")
    }

    @MainActor
    func currentPanelURLs() -> (left: URL, right: URL) {
        (appState.leftURL, appState.rightURL)
    }
}
