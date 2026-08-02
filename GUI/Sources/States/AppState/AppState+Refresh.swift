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

    func beginPanelNavigationLoading(for panel: FavPanelSide) {
        navigatingPanel = panel
        setLoading(panel, true)
        setSelectedFile(nil, for: panel)
        if panel == .left {
            displayedLeftFiles = []
        } else {
            displayedRightFiles = []
        }
        AutoFitScheduler.shared.prepareForNavigationLoading(panel: panel)
        log.debug("[Refresh] begin navigation loading panel=\(panel)")
    }

    /// Unified scanner directory setter — eliminates left/right branching at call sites.
    func setScannerDirectory(_ path: String, for panel: FavPanelSide) async {
        log.info("[Refresh] setScannerDirectory panel=\(panel) path='\(path)'")

        if panel == .left {
            await scanner.setLeftDirectory(pathStr: path)
        } else {
            await scanner.setRightDirectory(pathStr: path)
        }
    }

    /// Set scanner directory + refresh in one call.
    func setScannerDirectoryAndRefresh(_ path: String, for panel: FavPanelSide, force: Bool = false) async {
        guard PathUtils.areEqual(self.path(for: panel), path) else {
            log.debug("[Refresh] stale navigation skipped before watcher update panel=\(panel) path='\(path)'")
            return
        }
        await setScannerDirectory(path, for: panel)
        guard PathUtils.areEqual(self.path(for: panel), path) else {
            log.debug("[Refresh] stale navigation skipped before scan panel=\(panel) path='\(path)'")
            return
        }
        log.info("[Refresh] blocking refresh panel=\(panel) path='\(path)'")
        await refreshFiles(for: panel, force: force)
        log.info("[Refresh] blocking refresh completed panel=\(panel) path='\(path)'")
    }

}
