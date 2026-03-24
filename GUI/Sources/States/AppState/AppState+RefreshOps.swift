//
//  AppState+RefreshOps.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 24.03.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import FileModelKit
import Foundation

// MARK: - Refresh Operations
extension AppState {

    @Sendable
    func refreshFiles() async {
        await refreshFiles(for: .left)
        await refreshFiles(for: .right)
    }

    /// Refresh files for a specific panel
    func refreshFiles(for panel: FavPanelSide, force: Bool = false) async {
        log.debug("[REFRESH-FILES] ⏱ START panel=\(panel) force=\(force)")
        setLoading(panel, true)
        defer {
            setLoading(panel, false)
        }
        let panelURL = url(for: panel)
        if Self.isRemotePath(panelURL) {
            log.debug("[REFRESH-FILES] remote path detected, calling refreshRemoteFiles")
            await refreshRemoteFiles(for: panel)
        } else {
            log.debug("[REFRESH-FILES] local path, calling scanner.refreshFiles")
            await scanner.refreshFiles(currSide: panel, force: force)
            log.debug("[REFRESH-FILES] scanner.refreshFiles done")
        }
        if self[panel: panel].selectedFile == nil {
            let files = panel == .left ? displayedLeftFiles : displayedRightFiles
            if let f = firstRealFile(in: files) {
                setSelectedFile(f, for: panel)
                log.debug("[REFRESH-FILES] auto-selected \(f.nameStr) (\(panel))")
            }
        }
        log.debug("[REFRESH-FILES] ⏱ END panel=\(panel) loading=false")
    }

    func refreshLeftFiles() async { await refreshFiles(for: .left) }
    func refreshRightFiles() async { await refreshFiles(for: .right) }
}
