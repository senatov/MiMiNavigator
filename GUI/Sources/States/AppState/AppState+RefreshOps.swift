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

    // MARK: - Reconcile selection with the refreshed file list
    private func reconcileSelectionAfterRefresh(for panel: FavPanelSide) {
        let files = currentDisplayedFiles(for: panel)
        if let selected = self[panel: panel].selectedFile {
            let selectedURL = selected.urlValue.standardizedFileURL
            if let refreshedSelection = files.first(where: { $0.urlValue.standardizedFileURL == selectedURL }) {
                setSelectedFile(refreshedSelection, for: panel)
                return
            }
        }
        guard let file = firstRealFile(in: files) else {
            setSelectedFile(nil, for: panel)
            return
        }
        setSelectedFile(file, for: panel)
        log.debug("[REFRESH] selected first file \(file.nameStr) panel=\(panel)")
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
        guard !isTerminating else {
            log.info("[REFRESH] skip panel=\(panel) force=\(force) — app is terminating")
            return
        }

        log.debug("[REFRESH] start panel=\(panel) force=\(force)")
        setLoading(true, for: panel)
        defer {
            setLoading(false, for: panel)
            log.debug("[REFRESH] end panel=\(panel) loading=false")
        }

        await refreshDetectedFiles(for: panel, force: force)
        reconcileSelectionAfterRefresh(for: panel)
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
