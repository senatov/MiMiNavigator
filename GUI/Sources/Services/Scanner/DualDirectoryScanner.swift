// DualDirectoryScanner.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 11.12.24.
//  Copyright © 2024 Senatov. All rights reserved.
//

import Foundation
import SwiftUI

// MARK: - Actor for concurrent directory scanning
actor DualDirectoryScanner {
    let appState: AppState
    var fileCache = FileCache.shared
    private var leftTimer: DispatchSourceTimer?
    private var rightTimer: DispatchSourceTimer?

    // VNODE watchers — fire immediately when directory contents change (Archive Utility, etc.)
    private var leftVNode: DispatchSourceFileSystemObject?
    private var rightVNode: DispatchSourceFileSystemObject?
    private var leftFD: Int32 = -1
    private var rightFD: Int32 = -1

    /// Refresh interval from centralized constants
    private var refreshInterval: Int {
        Int(AppConstants.Scanning.refreshInterval)
    }

    init(appState: AppState) {
        self.appState = appState
    }

    // MARK: - Start monitoring both panels
    func startMonitoring() {
        log.info(#function)
        setupTimer(for: .left)
        setupTimer(for: .right)

        if leftTimer == nil || rightTimer == nil {
            log.error("Failed to initialize directory timers")
        }

        // Start vnode watchers for current paths
        Task { @MainActor in
            let lPath = appState.leftPath
            let rPath = appState.rightPath
            // Back on scanner actor to setup watchers
            await self.setupVNodeWatcher(for: .left, path: lPath)
            await self.setupVNodeWatcher(for: .right, path: rPath)
        }
    }

    // MARK: - Set directory for right panel
    func setRightDirectory(pathStr: String) {
        log.info("\(#function) path: \(pathStr)")
        Task { @MainActor in
            appState.rightPath = pathStr
        }
        setupVNodeWatcher(for: .right, path: pathStr)
    }

    // MARK: - Set directory for left panel
    func setLeftDirectory(pathStr: String) {
        log.info("\(#function) path: \(pathStr)")
        Task { @MainActor in
            appState.leftPath = pathStr
        }
        setupVNodeWatcher(for: .left, path: pathStr)
    }

    // MARK: - VNODE directory watcher (fires immediately on FS changes)
    /// Watches current directory of a panel using kqueue/vnode events.
    /// Fires on any write to the directory (file created/deleted/renamed by any process).
    private func setupVNodeWatcher(for side: PanelSide, path: String) {
        // Cancel previous watcher
        cancelVNodeWatcher(for: side)

        let fd = open(path, O_EVTONLY)
        guard fd >= 0 else {
            log.warning("[VNode] Cannot open fd for '\(path)': \(String(cString: strerror(errno)))")
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete, .link],
            queue: DispatchQueue.global(qos: .utility)
        )

        source.setEventHandler { [weak self] in
            guard let self else { return }
            log.debug("[VNode] Directory changed: '\(path)' side=\(side)")
            Task { @MainActor in
                await self.refreshFiles(currSide: side)
            }
        }

        source.setCancelHandler {
            close(fd)
        }

        source.resume()

        switch side {
        case .left:
            leftVNode = source
            leftFD = fd
        case .right:
            rightVNode = source
            rightFD = fd
        }

        log.debug("[VNode] Watching '\(path)' side=\(side)")
    }

    private func cancelVNodeWatcher(for side: PanelSide) {
        switch side {
        case .left:
            leftVNode?.cancel()
            leftVNode = nil
            leftFD = -1
        case .right:
            rightVNode?.cancel()
            rightVNode = nil
            rightFD = -1
        }
    }

    // MARK: - Setup refresh timer for a panel
    private func setupTimer(for side: PanelSide) {
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
        timer.schedule(deadline: .now(), repeating: .seconds(refreshInterval))
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
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

    // MARK: - Refresh files for a panel
    @Sendable
    func refreshFiles(currSide: PanelSide) async {
        log.info("⟳ \(#function) side: <<\(currSide)>>")
        let (path, showHidden): (String, Bool) = await MainActor.run {
            let p = currSide == .left ? appState.leftPath : appState.rightPath
            let h = UserPreferences.shared.snapshot.showHiddenFiles
            return (p, h)
        }

        log.info("📍 refreshFiles: path='\(path)', showHidden=\(showHidden), side=\(currSide)")

        let originalURL = URL(fileURLWithPath: path)
        let resolvedURL = originalURL.resolvingSymlinksInPath()

        log.info("🔗 originalURL: \(originalURL.path)")
        log.info("🔗 resolvedURL: \(resolvedURL.path)")
        if originalURL.path != resolvedURL.path {
            log.warning("⚠️ Path changed after symlink resolution: '\(originalURL.path)' → '\(resolvedURL.path)'")
        }

        // Try original URL first if resolved differs (symlink resolution can break /Volumes paths)
        let urlsToTry =
            originalURL.path != resolvedURL.path
            ? [originalURL, resolvedURL]
            : [resolvedURL]

        log.info("🔄 Will try \(urlsToTry.count) URL(s): \(urlsToTry.map(\.path))")

        for (index, url) in urlsToTry.enumerated() {
            log.info("🔄 Attempt \(index + 1)/\(urlsToTry.count): \(url.path)")
            do {
                let scanned = try FileScanner.scan(url: url, showHiddenFiles: showHidden)
                log.info("✅ Scan succeeded for \(url.path): \(scanned.count) items")
                await updateScannedFiles(scanned, for: currSide)
                await updateFileList(panelSide: currSide, with: scanned)
                return
            } catch let error as NSError {
                log.error("❌ Scan attempt \(index + 1) failed for \(url.path)")
                log.error("   error: \(error.localizedDescription)")
                log.error("   domain: \(error.domain), code: \(error.code)")
                if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError {
                    log.error("   underlying: domain=\(underlying.domain), code=\(underlying.code)")
                }
                if isPermissionDeniedError(error) {
                    log.warning("🔒 Permission denied for \(url.path), requesting access via BookmarkStore...")
                    let granted = await requestAndRetryAccess(for: url, side: currSide)
                    if granted {
                        log.info("✅ Access granted and rescan succeeded for \(url.path)")
                        return
                    }
                    log.warning("⛔ Access request failed or denied for \(url.path)")
                }
            }
        }

        log.error("💀 ALL scan attempts failed for <<\(currSide)>> path: '\(path)'")
    }

    // MARK: - Check if error is permission denied
    private func isPermissionDeniedError(_ error: NSError) -> Bool {
        if error.domain == NSCocoaErrorDomain && error.code == 257 { return true }
        if error.domain == NSPOSIXErrorDomain && error.code == 13 { return true }
        if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError {
            return isPermissionDeniedError(underlying)
        }
        return false
    }

    // MARK: - Request access and retry scan
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

    // MARK: - Update displayed files
    @MainActor
    private func updateScannedFiles(_ files: [CustomFile], for side: PanelSide) {
        let sorted = appState.applySorting(files)
        switch side {
            case .left: appState.displayedLeftFiles = sorted
            case .right: appState.displayedRightFiles = sorted
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
        leftTimer?.cancel(); leftTimer = nil
        rightTimer?.cancel(); rightTimer = nil
        cancelVNodeWatcher(for: .left)
        cancelVNodeWatcher(for: .right)
        log.info("[DualDirectoryScanner] stopMonitoring: all timers and vnode watchers cancelled")
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
