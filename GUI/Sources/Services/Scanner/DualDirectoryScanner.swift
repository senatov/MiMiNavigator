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

    /// Refresh interval from centralized constants
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
    /// showHiddenFiles must be read on MainActor before calling; use the async overload below.
    private func startFSEvents(for side: PanelSide, path: String) {
        guard !AppState.isRemotePath(path) else {
            log.debug("[FSEvents] Remote path — skip watcher: '\(path)' side=\(side)")
            stopFSEvents(for: side)
            return
        }
        // UserPreferences.shared is @MainActor-isolated — hop there to read, then launch watcher
        Task {
            let showHidden = await MainActor.run { UserPreferences.shared.snapshot.showHiddenFiles }
            await self.launchFSEventsWatcher(for: side, path: path, showHiddenFiles: showHidden)
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

    /// Merges FSEvents patch into the displayed file list without a full directory rescan.
    /// Only the files reported as changed are re-stat()ed — O(changed) not O(total).
    private func applyPatch(_ patch: FSEventsDirectoryWatcher.DirectoryPatch, for side: PanelSide) async {
        await MainActor.run {
            var current = side == .left ? appState.displayedLeftFiles : appState.displayedRightFiles
            // Remove deleted entries
            if !patch.removedPaths.isEmpty {
                let removedSet = Set(patch.removedPaths)
                let before = current.count
                current.removeAll { removedSet.contains($0.pathStr) }
                log.debug("[FSEvents patch] removed \(before - current.count) item(s) from \(side)")
            }
            // Upsert added/modified entries
            for updated in patch.addedOrModified {
                if let idx = current.firstIndex(where: { $0.pathStr == updated.pathStr }) {
                    current[idx] = updated
                } else {
                    current.append(updated)
                }
            }
            if !patch.addedOrModified.isEmpty {
                log.debug("[FSEvents patch] upserted \(patch.addedOrModified.count) item(s) into \(side)")
            }
            let sorted = appState.applySorting(current)
            switch side {
                case .left: appState.displayedLeftFiles = sorted
                case .right: appState.displayedRightFiles = sorted
            }
        }
    }

    // MARK: - Polling timer (safety net)

    private func setupTimer(for side: PanelSide) {
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
        timer.schedule(deadline: .now(), repeating: .seconds(refreshInterval))
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                await self.refreshFiles(currSide: side)
            }
        }
        timer.resume()
        switch side {
            case .left: leftTimer = timer
            case .right: rightTimer = timer
        }
    }

    // MARK: - Full refresh (used by timer safety net and explicit navigation)

    @Sendable
    func refreshFiles(currSide: PanelSide) async {
        let (path, showHidden): (String, Bool) = await MainActor.run {
            let p = currSide == .left ? appState.leftPath : appState.rightPath
            let h = UserPreferences.shared.snapshot.showHiddenFiles
            return (p, h)
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
                let capturedShowHidden = showHidden
                let scanned =
                    try await Task.detached(priority: .userInitiated) {
                        try FileScanner.scan(url: url, showHiddenFiles: capturedShowHidden)
                    }
                    .value
                log.info("[Scan] Succeeded for \(url.path): \(scanned.count) items")
                await updateScannedFiles(scanned, for: currSide)
                await updateFileList(panelSide: currSide, with: scanned)
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
        log.info("🔐 requestAndRetryAccess: requesting bookmark for \(url.path)")
        let granted = await BookmarkStore.shared.requestAccessPersisting(for: url)
        log.info("🔐 BookmarkStore result: granted=\(granted) for \(url.path)")
        guard granted else { return false }
        do {
            let showHidden = await MainActor.run { UserPreferences.shared.snapshot.showHiddenFiles }
            let scanned = try FileScanner.scan(url: url, showHiddenFiles: showHidden)
            log.info("✅ Rescan after access grant: \(scanned.count) items from \(url.path)")
            await updateScannedFiles(scanned, for: side)
            await updateFileList(panelSide: side, with: scanned)
            return true
        } catch {
            log.error("❌ Rescan STILL failed after access granted for \(url.path): \(error)")
            return false
        }
    }

    // MARK: - Update displayed files (full replace — used by polling timer)

    @MainActor
    private func updateScannedFiles(_ files: [CustomFile], for side: PanelSide) {
        let sorted = appState.applySorting(files)
        let current = side == .left ? appState.displayedLeftFiles : appState.displayedRightFiles
        guard sorted.map(\.id) != current.map(\.id) else { return }
        switch side {
            case .left: appState.displayedLeftFiles = sorted
            case .right: appState.displayedRightFiles = sorted
        }
        log.debug("[Scanner] Full update \(side) panel: \(sorted.count) items")
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
