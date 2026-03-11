// AppState+Navigation.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 11.03.2026.
// Copyright © 2025-2026 Senatov. All rights reserved.
// Description: Directory navigation with retry + spinner for slow volumes, parent nav

import AppKit
import FileModelKit
import Foundation

// MARK: - Directory Navigation (retry + spinner for slow volumes)
extension AppState {

    /// Navigate into a directory with retry logic and spinner for slow volumes (USB, NAS).
    /// Shows a loading overlay, waits for files to appear, retries up to 3 times.
    func navigateToDirectory(_ newPath: String, on panel: PanelSide) async {
        let previousPath = panel == .left ? leftPath : rightPath
        log.info("[Navigate] \(panel): '\(previousPath)' → '\(newPath)'")

        updatePath(newPath, for: panel)
        if panel == .left { selectedLeftFile = nil } else { selectedRightFile = nil }
        multiSelectionManager?.resetAnchor(for: panel)

        // Show spinner after small delay — avoids flicker for fast local dirs
        let spinnerTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(200))
            if !Task.isCancelled {
                navigatingPanel = panel
            }
        }

        defer {
            spinnerTask.cancel()
            navigatingPanel = nil
        }

        // Retry loop: slow volumes (USB/NAS) may need a moment for I/O
        let maxAttempts = 3
        for attempt in 1...maxAttempts {
            await scanner.clearCooldown(for: panel)

            if panel == .left {
                await scanner.setLeftDirectory(pathStr: newPath)
                await refreshLeftFiles()
            } else {
                await scanner.setRightDirectory(pathStr: newPath)
                await refreshRightFiles()
            }

            let files = displayedFiles(for: panel)
            let currentPath = panel == .left ? leftPath : rightPath
            if !files.isEmpty && PathUtils.areEqual(currentPath, newPath) {
                log.info("[Navigate] \(panel): SUCCESS on attempt \(attempt), \(files.count) files")
                return
            }

            if attempt < maxAttempts {
                log.warning("[Navigate] \(panel): attempt \(attempt) got 0 files, retrying in 1s...")
                try? await Task.sleep(for: .seconds(1))

                let nowPath = panel == .left ? leftPath : rightPath
                if !PathUtils.areEqual(nowPath, newPath) {
                    log.info("[Navigate] \(panel): path changed externally, aborting retry")
                    return
                }
            }
        }

        let finalFiles = displayedFiles(for: panel)
        let finalPath = panel == .left ? leftPath : rightPath
        if finalFiles.isEmpty || !PathUtils.areEqual(finalPath, newPath) {
            log.error("[Navigate] \(panel): FAILED after \(maxAttempts) attempts, staying on previous path")
            updatePath(previousPath, for: panel)
            if panel == .left {
                await scanner.setLeftDirectory(pathStr: previousPath)
                await refreshLeftFiles()
            } else {
                await scanner.setRightDirectory(pathStr: previousPath)
                await refreshRightFiles()
            }
        }
    }

    /// Handle ".." (parent directory) navigation — archive-aware
    func navigateToParent(on panel: PanelSide) async {
        let state = archiveState(for: panel)
        let currentPath = panel == .left ? leftPath : rightPath

        // Remote path — navigate up via RemoteConnectionManager
        if Self.isRemotePath(currentPath) {
            let manager = RemoteConnectionManager.shared
            guard let conn = manager.activeConnection else { return }
            let parentRemote = (conn.currentPath as NSString).deletingLastPathComponent
            let normalizedParent = parentRemote.isEmpty ? "/" : parentRemote
            log.info("[AppState] navigateToParent remote: \(conn.currentPath) -> \(normalizedParent)")
            do {
                let items = try await manager.listDirectory(normalizedParent)
                let files = items.map { CustomFile(remoteItem: $0) }
                let sorted = applySorting(files)
                let mountPath = conn.provider.mountPath
                let displayPath = mountPath.hasSuffix("/") ? String(mountPath.dropLast()) : mountPath
                updatePath(displayPath + normalizedParent, for: panel)
                switch panel {
                case .left:
                    displayedLeftFiles = sorted
                    selectedLeftFile = firstRealFile(sorted)
                case .right:
                    displayedRightFiles = sorted
                    selectedRightFile = firstRealFile(sorted)
                }
            } catch {
                log.error("[AppState] remote navigateToParent failed: \(error.localizedDescription)")
            }
            return
        }

        // If at the root of an extracted archive → exit archive entirely
        if state.isInsideArchive && state.isAtArchiveRoot(currentPath: currentPath) {
            await exitArchive(on: panel)
            return
        }

        // Normal parent navigation — use retry+spinner for slow volumes
        let parentURL = URL(fileURLWithPath: currentPath).deletingLastPathComponent()
        await navigateToDirectory(parentURL.path, on: panel)
    }

    // MARK: - Navigation History Helpers

    /// Get navigation history for specified panel
    func navigationHistory(for panel: PanelSide) -> PanelNavigationHistory {
        panel == .left ? leftNavigationHistory : rightNavigationHistory
    }

    /// Record navigation to path (called when entering directories)
    func recordNavigation(to path: String, panel: PanelSide) {
        guard !isNavigatingFromHistory else { return }
        navigationHistory(for: panel).navigateTo(path)
    }
}
