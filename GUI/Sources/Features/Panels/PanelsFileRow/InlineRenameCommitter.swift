// InlineRenameCommitter.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 09.07.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Shared inline rename helpers for all panel display modes.

import FileModelKit
import Foundation

// MARK: - Inline Rename Committer
@MainActor
enum InlineRenameCommitter {

    // MARK: - Active State
    static func isActive(file: CustomFile, panel: FavPanelSide, appState: AppState) -> Bool {
        appState.inlineRename.activeFileID == AnyHashable(file.id)
            && appState.inlineRename.panelTag == panelTag(for: panel)
    }

    // MARK: - Commit
    static func commit(file: CustomFile, panel: FavPanelSide, appState: AppState) {
        guard let result = appState.inlineRename.commit() else { return }
        let resultPanel = panelSide(for: result.panelTag)
        guard resultPanel == panel else {
            log.warning("[Rename] inline commit panel mismatch: expected=\(panel) result=\(resultPanel)")
            return
        }
        Task {
            await CntMenuCoord.shared.performRename(
                file: file,
                newName: result.newName,
                panel: panel,
                appState: appState
            )
        }
    }

    // MARK: - Panel Tag
    private static func panelTag(for panel: FavPanelSide) -> Int {
        panel == .left ? 0 : 1
    }

    // MARK: - Panel Side
    private static func panelSide(for tag: Int) -> FavPanelSide {
        tag == 0 ? .left : .right
    }
}
