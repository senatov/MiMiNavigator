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
    func setScannerDirectory(_ path: String, for panel: FavPanelSide) async {
        log.info("[Refresh] setScannerDirectory panel=\(panel) path='\(path)'")

        if panel == .left {
            await scanner.setLeftDirectory(pathStr: path)
        } else {
            await scanner.setRightDirectory(pathStr: path)
        }
    }

    /// Set scanner directory + refresh in one call.
    func setScannerDirectoryAndRefresh(_ path: String, for panel: FavPanelSide) async {
        await setScannerDirectory(path, for: panel)

        if Self.isMountedVolumeRootPath(path) {
            log.info("[Refresh] mounted volume root → background refresh panel=\(panel) path='\(path)'")

            Task { [weak self] in
                guard let self else { return }
                await self.refreshFiles(for: panel)
                log.info("[Refresh] mounted volume background refresh completed panel=\(panel) path='\(path)'")
            }

            return
        }

        log.info("[Refresh] blocking refresh panel=\(panel) path='\(path)'")
        await refreshFiles(for: panel)
        log.info("[Refresh] blocking refresh completed panel=\(panel) path='\(path)'")
    }

}
