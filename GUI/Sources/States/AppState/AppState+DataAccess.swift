// AppState+DataAccess.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 15.03.2026.
// Copyright © 2025-2026 Senatov. All rights reserved.
// Description: Data access helpers — uses PanelState directly.

import FileModelKit
import Foundation

// MARK: - Data Access
extension AppState {

    func displayedFiles(for panel: PanelSide) -> [CustomFile] {
        let raw = panel == .left ? displayedLeftFiles : displayedRightFiles
        let query = self[panel: panel].filterQuery.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return raw }
        let lower = query.lowercased()
        return raw.filter { $0.nameStr.lowercased().contains(lower) }
    }

    func pathURL(for panel: PanelSide) -> URL? {
        url(for: panel)
    }

    func tabManager(for panel: PanelSide) -> TabManager {
        panel == .left ? leftTabManager : rightTabManager
    }

    func archiveState(for panel: PanelSide) -> ArchiveNavigationState {
        self[panel: panel].archiveState
    }

    func setArchiveState(_ state: ArchiveNavigationState, for panel: PanelSide) {
        self[panel: panel].archiveState = state
    }

    func showHiddenFilesSnapshot() -> Bool {
        UserPreferences.shared.snapshot.showHiddenFiles
    }
}
