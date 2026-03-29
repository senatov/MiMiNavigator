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

    private func currentDisplayedFiles(for panel: FavPanelSide) -> [CustomFile] {
        panel == .left ? displayedLeftFiles : displayedRightFiles
    }

    private func autoSelectFirstRealFileIfNeeded(for panel: FavPanelSide) {
        guard self[panel: panel].selectedFile == nil else { return }
        guard let file = firstRealFile(in: currentDisplayedFiles(for: panel)) else { return }

        setSelectedFile(file, for: panel)
        log.debug("[REFRESH] auto-selected \(file.nameStr) panel=\(panel)")
    }

    private func setLoading(_ isLoading: Bool, for panel: FavPanelSide) {
        setLoading(panel, isLoading)
    }

    private func refreshBothPanels() async {
        await refreshFiles(for: .left)
        await refreshFiles(for: .right)
    }

    @Sendable
    func refreshPanels() async {
        await refreshBothPanels()
    }

    @Sendable
    func refreshFiles() async {
        await refreshPanels()
    }

    /// Refresh a panel using route detection.
    /// Remote panels go through remote listing only. Local panels go through the scanner pipeline.
    func refreshPanel(for panel: FavPanelSide, force: Bool = false) async {
        log.debug("[REFRESH] start panel=\(panel) force=\(force)")
        setLoading(true, for: panel)
        defer {
            setLoading(false, for: panel)
            log.debug("[REFRESH] end panel=\(panel) loading=false")
        }

        await refreshDetectedFiles(for: panel, force: force)
        autoSelectFirstRealFileIfNeeded(for: panel)
    }

    /// Backward-compatible wrapper.
    func refreshFiles(for panel: FavPanelSide, force: Bool = false) async {
        await refreshPanel(for: panel, force: force)
    }

    func refreshLeftFiles() async {
        await refreshPanel(for: .left)
    }

    func refreshRightFiles() async {
        await refreshPanel(for: .right)
    }
}
