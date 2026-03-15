// AppState+Navigation.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 11.03.2026.
// Copyright © 2025-2026 Senatov. All rights reserved.
// Description: Directory navigation with retry + spinner for slow volumes, parent nav.
//              Uses setScannerDirectoryAndRefresh to avoid left/right branching.

import AppKit
import FileModelKit
import Foundation

// MARK: - Directory Navigation
extension AppState {

    /// Navigate into a directory with retry logic and spinner for slow volumes (USB, NAS).
    func navigateToDirectory(_ newPath: String, on panel: PanelSide) async {
        let previousPath = path(for: panel)
        log.info("[Navigate] \(panel): '\(previousPath)' → '\(newPath)'")
        updatePath(newPath, for: panel)
        setSelectedFile(nil, for: panel)
        multiSelectionManager?.resetAnchor(for: panel)
        let spinnerTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(200))
            if !Task.isCancelled { navigatingPanel = panel }
        }
        defer {
            spinnerTask.cancel()
            navigatingPanel = nil
        }
        let maxAttempts = 3
        for attempt in 1...maxAttempts {
            await scanner.clearCooldown(for: panel)
            await setScannerDirectoryAndRefresh(newPath, for: panel)
            let files = displayedFiles(for: panel)
            if !files.isEmpty && PathUtils.areEqual(path(for: panel), newPath) {
                log.info("[Navigate] \(panel): SUCCESS on attempt \(attempt), \(files.count) files")
                return
            }
            if attempt < maxAttempts {
                log.warning("[Navigate] \(panel): attempt \(attempt) got 0 files, retrying in 1s...")
                try? await Task.sleep(for: .seconds(1))
                if !PathUtils.areEqual(path(for: panel), newPath) {
                    log.info("[Navigate] \(panel): path changed externally, aborting retry")
                    return
                }
            }
        }
        if displayedFiles(for: panel).isEmpty || !PathUtils.areEqual(path(for: panel), newPath) {
            log.error("[Navigate] \(panel): FAILED after \(maxAttempts) attempts, staying on previous path")
            updatePath(previousPath, for: panel)
            await setScannerDirectoryAndRefresh(previousPath, for: panel)
        }
    }

    /// Handle ".." (parent directory) navigation — archive-aware
    func navigateToParent(on panel: PanelSide) async {
        let state = archiveState(for: panel)
        let currentURL = url(for: panel)
        let currentPath = currentURL.path
        if Self.isRemotePath(currentURL) {
            await navigateToParentRemote(on: panel)
            return
        }
        if state.isInsideArchive && state.isAtArchiveRoot(currentPath: currentPath) {
            await exitArchive(on: panel)
            return
        }
        let parentURL = currentURL.deletingLastPathComponent()
        guard parentURL.path != currentPath else {
            log.debug("[Navigate] \(panel): already at filesystem root")
            return
        }
        await navigateToDirectory(parentURL.path, on: panel)
    }

    /// Remote parent navigation
    private func navigateToParentRemote(on panel: PanelSide) async {
        let manager = RemoteConnectionManager.shared
        guard let conn = manager.activeConnection else { return }
        let parentRemote = (conn.currentPath as NSString).deletingLastPathComponent
        let normalizedParent = parentRemote.isEmpty ? "/" : parentRemote
        log.info("[AppState] navigateToParent remote: \(conn.currentPath) → \(normalizedParent)")
        do {
            let items = try await manager.listDirectory(normalizedParent)
            let files = items.map { CustomFile(remoteItem: $0) }
            let sorted = applySorting(files)
            let mountPath = conn.provider.mountPath
            let displayPath = mountPath.hasSuffix("/") ? String(mountPath.dropLast()) : mountPath
            updatePath(displayPath + normalizedParent, for: panel)
            if panel == .left { displayedLeftFiles = sorted } else { displayedRightFiles = sorted }
            setSelectedFile(firstRealFile(in: sorted), for: panel)
        } catch {
            log.error("[AppState] remote navigateToParent failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Navigation History
    func navigationHistory(for panel: PanelSide) -> PanelNavigationHistory {
        panel == .left ? leftNavigationHistory : rightNavigationHistory
    }

    func recordNavigation(to path: String, panel: PanelSide) {
        guard !isNavigatingFromHistory else { return }
        let url = URL(fileURLWithPath: path).standardizedFileURL
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
            navigationHistory(for: panel).navigateTo(url)
        }
    }
}
