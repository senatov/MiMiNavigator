// AppState+Refresh.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 11.03.2026.
// Copyright © 2025-2026 Senatov. All rights reserved.
// Description: Panel refresh, remote listing, path updates, scanner directory helper.

import FileModelKit
import Foundation

// MARK: - Scanner Directory Helper
extension AppState {

    /// Unified scanner directory setter — eliminates left/right branching at call sites.
    func setScannerDirectory(_ path: String, for panel: PanelSide) async {
        if panel == .left {
            await scanner.setLeftDirectory(pathStr: path)
        } else {
            await scanner.setRightDirectory(pathStr: path)
        }
    }

    /// Set scanner directory + refresh in one call.
    func setScannerDirectoryAndRefresh(_ path: String, for panel: PanelSide) async {
        await setScannerDirectory(path, for: panel)
        await refreshFiles(for: panel)
    }
}

// MARK: - Refresh Operations
extension AppState {

    @Sendable
    func refreshFiles() async {
        await refreshFiles(for: .left)
        await refreshFiles(for: .right)
    }

    func refreshFiles(for panel: PanelSide) async {
        let panelURL = url(for: panel)
        if Self.isRemotePath(panelURL) {
            await refreshRemoteFiles(for: panel)
        } else {
            await scanner.refreshFiles(currSide: panel)
        }
        if self[panel: panel].selectedFile == nil {
            let files = panel == .left ? displayedLeftFiles : displayedRightFiles
            if let f = firstRealFile(in: files) {
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

    nonisolated static func isRemotePath(_ url: URL) -> Bool {
        // Check direct scheme first (clean case)
        let scheme = url.scheme ?? ""
        if scheme == "sftp" || scheme == "ftp" { return true }
        // Catch mangled URLs like file:///...Container/Data/ftp://host
        // that happen when remote URL got wrapped in fileURLWithPath()
        let raw = url.absoluteString
        let markers = ["ftp://", "sftp://", "/ftp:", "/sftp:"]
        return markers.contains { raw.contains($0) }
    }

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
            if panel == .left { displayedLeftFiles = sorted } else { displayedRightFiles = sorted }
            if self[panel: panel].selectedFile == nil {
                setSelectedFile(firstRealFile(in: sorted), for: panel)
            }
        } catch {
            log.error("[AppState] remote listing failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - Path Updates
extension AppState {

    func updatePath(_ pathString: String, for panel: PanelSide) {
        // remote strings must go through URL(string:) — not fileURLWithPath, that mangles them
        if pathString.hasPrefix("sftp://") || pathString.hasPrefix("ftp://") {
            guard let remoteURL = URL(string: pathString) else {
                log.error("\(#function) bad remote URL string: \(pathString)")
                return
            }
            log.debug("\(#function) remote path detected, using URL(string:) for \(pathString)")
            updatePath(remoteURL, for: panel)
            return
        }
        updatePath(URL(fileURLWithPath: pathString), for: panel)
    }

    func updatePath(_ newURL: URL, for panel: PanelSide) {
        // guard: mangled remote URL wrapped in fileURLWithPath — bail early
        if Self.isRemotePath(newURL) && newURL.scheme == "file" {
            log.warning("\(#function) mangled remote URL detected: \(newURL.absoluteString) — skipping local update")
            return
        }
        let currentURL = url(for: panel)
        guard !PathUtils.areEqual(currentURL, newURL) else { return }
        var normalizedURL = newURL
        var isDirForFileCheck: ObjCBool = false
        if FileManager.default.fileExists(atPath: newURL.path, isDirectory: &isDirForFileCheck),
           !isDirForFileCheck.boolValue {
            normalizedURL = newURL.deletingLastPathComponent()
            log.debug("\(#function) file → parent dir: \(normalizedURL.path)")
        }
        log.debug("\(#function) \(panel) → \(normalizedURL.path)")
        focusedPanel = panel
        tabManager(for: panel).updateActiveTabPath(normalizedURL)
        if !isNavigatingFromHistory {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: normalizedURL.path, isDirectory: &isDir),
               isDir.boolValue {
                navigationHistory(for: panel).navigateTo(normalizedURL)
            }
            selectionsHistory.setCurrent(to: normalizedURL)
        }
        let panelURL = url(for: panel)
        if Self.isRemotePath(normalizedURL) && !Self.isRemotePath(panelURL) {
            self[panel: panel].savedLocalURL = panelURL
        }
        if panel == .left { leftURL = normalizedURL } else { rightURL = normalizedURL }
        let files = panel == .left ? displayedLeftFiles : displayedRightFiles
        setSelectedFile(firstRealFile(in: files), for: panel)
    }

    func restoreLocalPath(for panel: PanelSide) async {
        guard let localURL = self[panel: panel].savedLocalURL else {
            log.warning("[AppState] no saved local path for \(panel)")
            return
        }
        log.info("[AppState] restoring local path \(panel): \(localURL.path)")
        updatePath(localURL, for: panel)
        await setScannerDirectoryAndRefresh(localURL.path, for: panel)
    }
}
