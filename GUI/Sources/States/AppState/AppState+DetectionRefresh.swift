//
//  AppState+DetectionRefresh.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 24.03.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import FileModelKit
import Foundation

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

    func isRemotePanel(_ panel: FavPanelSide) -> Bool {
        Self.isRemotePath(url(for: panel))
    }

    func refreshDetectedFiles(for panel: FavPanelSide, force: Bool = false) async {
        if isRemotePanel(panel) {
            log.debug("[AppState] refreshDetectedFiles routing to remote panel=\(panel)")
            await refreshRemoteFiles(for: panel)
            return
        }

        log.debug("[AppState] refreshDetectedFiles routing to local scanner panel=\(panel) force=\(force)")
        await scanner.refreshFiles(currSide: panel, force: force)
    }

    private func clearDisplayedFilesForRemoteRefresh(_ panel: FavPanelSide) {
        if panel == .left {
            displayedLeftFiles = []
        } else {
            displayedRightFiles = []
        }
    }

    private func applyRemoteFiles(_ files: [CustomFile], to panel: FavPanelSide) {
        if panel == .left {
            displayedLeftFiles = files
        } else {
            displayedRightFiles = files
        }
    }

    func refreshRemoteFiles(for panel: FavPanelSide) async {
        let panelURL = url(for: panel)
        guard Self.isRemotePath(panelURL) else {
            log.warning("[AppState] refreshRemoteFiles called for local panel=\(panel) url=\(panelURL.absoluteString)")
            return
        }

        let manager = RemoteConnectionManager.shared
        guard manager.activeConnection != nil else {
            log.error("[AppState] refreshRemoteFiles — no active connection")
            clearDisplayedFilesForRemoteRefresh(panel)
            setSelectedFile(nil, for: panel)
            return
        }

        clearDisplayedFilesForRemoteRefresh(panel)
        setSelectedFile(nil, for: panel)

        do {
            // Use panel URL path — NOT conn.currentPath which may lag behind navigation.
            let remotePath = panelURL.path.isEmpty ? "/" : panelURL.path
            log.info("[AppState] refreshRemoteFiles panel=\(panel) path=\(remotePath)")

            let items = try await manager.listDirectory(remotePath)
            let files = items.map { CustomFile(remoteItem: $0) }
            let sorted = applySorting(files)

            applyRemoteFiles(sorted, to: panel)

            if let currentSelection = self[panel: panel].selectedFile,
               sorted.contains(where: { $0.id == currentSelection.id }) {
                setSelectedFile(currentSelection, for: panel)
            } else {
                setSelectedFile(firstRealFile(in: sorted), for: panel)
            }

            log.info("[AppState] refreshRemoteFiles done panel=\(panel) path=\(remotePath) items=\(sorted.count)")
        } catch {
            log.error("[AppState] remote listing failed panel=\(panel): \(error.localizedDescription)")
            clearDisplayedFilesForRemoteRefresh(panel)
            setSelectedFile(nil, for: panel)
        }
    }
}
