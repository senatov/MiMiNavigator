// AppState+Refresh.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 11.03.2026.
// Copyright © 2025-2026 Senatov. All rights reserved.
// Description: Panel refresh operations, remote file listing, path updates

import FileModelKit
import Foundation

// MARK: - Refresh Operations
extension AppState {

    @Sendable
    func refreshFiles() async {
        await refreshLeftFiles()
        await refreshRightFiles()
    }

    func refreshLeftFiles() async {
        if Self.isRemotePath(leftPath) {
            await refreshRemoteFiles(for: .left)
        } else {
            await scanner.refreshFiles(currSide: .left)
        }
        if selectedLeftFile == nil {
            selectedLeftFile = firstRealFile(in: displayedLeftFiles)
            if let f = selectedLeftFile {
                log.debug("[AppState] 👆 \(f.nameStr) selected (left)")
            }
        }
    }

    func refreshRightFiles() async {
        if Self.isRemotePath(rightPath) {
            await refreshRemoteFiles(for: .right)
        } else {
            await scanner.refreshFiles(currSide: .right)
        }
        if selectedRightFile == nil {
            selectedRightFile = firstRealFile(in: displayedRightFiles)
            if let f = selectedRightFile {
                log.debug("[AppState] 👆 \(f.nameStr) selected (right)")
            }
        }
    }
}

// MARK: - Remote Path Detection & Refresh
extension AppState {

    /// Returns true if the path belongs to an active remote connection
    nonisolated static func isRemotePath(_ path: String) -> Bool {
        path.hasPrefix("sftp://") || path.hasPrefix("ftp://") || path.hasPrefix("/sftp:") || path.hasPrefix("/ftp:")
    }

    /// Fetch remote directory listing and populate panel files
    func refreshRemoteFiles(for panel: PanelSide) async {
        let manager = RemoteConnectionManager.shared
        guard let conn = manager.activeConnection else {
            log.error("[AppState] refreshRemoteFiles — no active connection")
            return
        }
        do {
            let remotePath = conn.currentPath
            log.info("[AppState] refreshRemoteFiles panel=\(panel) path=\(remotePath)")
            let items = try await manager.listDirectory(remotePath)
            let files = items.map { CustomFile(remoteItem: $0) }
            let sorted = applySorting(files)
            switch panel {
                case .left:
                    displayedLeftFiles = sorted
                    if selectedLeftFile == nil { selectedLeftFile = firstRealFile(in: sorted) }
                case .right:
                    displayedRightFiles = sorted
                    if selectedRightFile == nil { selectedRightFile = firstRealFile(in: sorted) }
            }
        } catch {
            log.error("[AppState] remote listing failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - Path Updates
extension AppState {

    func updatePath(_ path: String, for panelSide: PanelSide) {
        let currentPath = panelSide == .left ? leftPath : rightPath

        guard !PathUtils.areEqual(currentPath, path) else { return }

        log.debug("[AppState] updatePath \(panelSide) → \(path)")
        focusedPanel = panelSide

        tabManager(for: panelSide).updateActiveTabPath(path)

        if !isNavigatingFromHistory {
            navigationHistory(for: panelSide).navigateTo(path)
            selectionsHistory.add(path)
        }

        switch panelSide {
            case .left:
                if Self.isRemotePath(path) && !Self.isRemotePath(leftPath) {
                    savedLocalLeftPath = leftPath
                }
                leftPath = path
                selectedLeftFile = firstRealFile(in: displayedLeftFiles)
            case .right:
                if Self.isRemotePath(path) && !Self.isRemotePath(rightPath) {
                    savedLocalRightPath = rightPath
                }
                rightPath = path
                selectedRightFile = firstRealFile(in: displayedRightFiles)
        }
    }

    /// Restore panel to saved local path after remote disconnect
    func restoreLocalPath(for panel: PanelSide) async {
        let saved: String?
        switch panel {
            case .left: saved = savedLocalLeftPath
            case .right: saved = savedLocalRightPath
        }
        guard let localPath = saved else {
            log.warning("[AppState] no saved local path for \(panel)")
            return
        }
        log.info("[AppState] restoring local path \(panel): \(localPath)")
        updatePath(localPath, for: panel)
        if panel == .left {
            await scanner.setLeftDirectory(pathStr: localPath)
            await refreshLeftFiles()
        } else {
            await scanner.setRightDirectory(pathStr: localPath)
            await refreshRightFiles()
        }
    }
}
