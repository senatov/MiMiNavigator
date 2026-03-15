// AppState+DataAccess.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 15.03.2026.
// Copyright © 2025-2026 Senatov. All rights reserved.
// Description: Data access helpers — displayedFiles, pathURL, tabManager, archiveState

import FileModelKit
import Foundation

// MARK: - Data Access
extension AppState {

    func displayedFiles(for panelSide: PanelSide) -> [CustomFile] {
        let raw: [CustomFile]
        let query: String
        switch panelSide {
            case .left:
                raw = displayedLeftFiles
                query = leftFilterQuery
            case .right:
                raw = displayedRightFiles
                query = rightFilterQuery
        }
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return raw }
        let lower = trimmed.lowercased()
        return raw.filter { $0.nameStr.lowercased().contains(lower) }
    }

    func pathURL(for panelSide: PanelSide) -> URL? {
        url(for: panelSide)
    }

    func tabManager(for panel: PanelSide) -> TabManager {
        panel == .left ? leftTabManager : rightTabManager
    }

    func archiveState(for panel: PanelSide) -> ArchiveNavigationState {
        panel == .left ? leftArchiveState : rightArchiveState
    }

    func setArchiveState(_ state: ArchiveNavigationState, for panel: PanelSide) {
        if panel == .left { leftArchiveState = state } else { rightArchiveState = state }
    }

    func showHiddenFilesSnapshot() -> Bool {
        UserPreferences.shared.snapshot.showHiddenFiles
    }
}
