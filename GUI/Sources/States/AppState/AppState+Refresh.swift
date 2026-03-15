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

    // MARK: - Unified refresh for one panel
    func refreshFiles(for panel: PanelSide) async {
        let panelURL = url(for: panel)
        if Self.isRemotePath(panelURL) {
            await refreshRemoteFiles(for: panel)
        } else {
            await scanner.refreshFiles(currSide: panel)
        }
        let selected = panel == .left ? selectedLeftFile : selectedRightFile
        if selected == nil {
            let files = panel == .left ? displayedLeftFiles : displayedRightFiles
            let first = firstRealFile(in: files)
            if let f = first {
                setSelectedFile(f, for: panel)
                log.debug("[AppState] \(f.nameStr) selected (\(panel))")
            }
        }
    }

    func refreshLeftFiles() async { await refreshFiles(for: .left) }
    func refreshRightFiles() async { await refreshFiles(for: .right) }
}

// MARK: - Remote Path Detection & Refresh
extension AppState {

    /// Returns true if the URL belongs to an active remote connection
    nonisolated static func isRemotePath(_ url: URL) -> Bool {
        let path = url.absoluteString
        return path.hasPrefix("sftp://")
            || path.hasPrefix("ftp://")
            || path.hasPrefix("/sftp:")
            || path.hasPrefix("/ftp:")
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

    /// Convenience overload: accepts a String path and converts to URL internally.
    func updatePath(_ pathString: String, for panelSide: PanelSide) {
        updatePath(URL(fileURLWithPath: pathString), for: panelSide)
    }

    func updatePath(_ newURL: URL, for panelSide: PanelSide) {
        let currentURL = url(for: panelSide)
        guard !PathUtils.areEqual(currentURL, newURL) else { return }
        var normalizedURL = newURL
        var isDirForFileCheck: ObjCBool = false
        if FileManager.default.fileExists(atPath: newURL.path, isDirectory: &isDirForFileCheck),
           !isDirForFileCheck.boolValue {
            normalizedURL = newURL.deletingLastPathComponent()
            log.debug("[AppState] updatePath: file detected, using parent directory → \(normalizedURL.path)")
        }
        log.debug("[AppState] updatePath \(panelSide) → \(normalizedURL.path)")
        focusedPanel = panelSide
        tabManager(for: panelSide).updateActiveTabPath(normalizedURL)
        if !isNavigatingFromHistory {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: normalizedURL.path, isDirectory: &isDir),
               isDir.boolValue {
                navigationHistory(for: panelSide).navigateTo(normalizedURL)
            }
            selectionsHistory.setCurrent(to: normalizedURL)
        }
        switch panelSide {
        case .left:
            if Self.isRemotePath(normalizedURL) && !Self.isRemotePath(leftURL) {
                savedLocalLeftURL = leftURL
            }
            leftURL = normalizedURL
            selectedLeftFile = firstRealFile(in: displayedLeftFiles)
        case .right:
            if Self.isRemotePath(normalizedURL) && !Self.isRemotePath(rightURL) {
                savedLocalRightURL = rightURL
            }
            rightURL = normalizedURL
            selectedRightFile = firstRealFile(in: displayedRightFiles)
        }
    }

    /// Restore panel to saved local path after remote disconnect
    func restoreLocalPath(for panel: PanelSide) async {
        let savedURL: URL? = panel == .left ? savedLocalLeftURL : savedLocalRightURL
        guard let localURL = savedURL else {
            log.warning("[AppState] no saved local path for \(panel)")
            return
        }
        log.info("[AppState] restoring local path \(panel): \(localURL.path)")
        updatePath(localURL, for: panel)
        if panel == .left {
            await scanner.setLeftDirectory(pathStr: localURL.path)
        } else {
            await scanner.setRightDirectory(pathStr: localURL.path)
        }
        await refreshFiles(for: panel)
    }
}
