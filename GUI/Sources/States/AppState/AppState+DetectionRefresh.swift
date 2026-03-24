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
