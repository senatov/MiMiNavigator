// TableDropHandler.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 27.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Drop handler for FileTableView panel background

import FileModelKit
import SwiftUI


// MARK: - TableDropHandler
/// Handles files dropped on the panel background (not on a specific row/folder).
@MainActor
struct TableDropHandler {
    let panelSide: FavPanelSide
    let appState: AppState
    let dragDropManager: DragDropManager


    // MARK: - Handle Panel Drop
    func handlePanelDrop(_ droppedFiles: [CustomFile]) -> Bool {
        guard !droppedFiles.isEmpty else { return false }
        let destinationURL = appState.url(for: panelSide)
        let sourceSide: FavPanelSide? = panelSide == .left ? .right : .left
        dragDropManager.prepareTransfer(files: droppedFiles, to: destinationURL, from: sourceSide)
        log.info("[TableDrop] \(droppedFiles.count) file(s) → \(destinationURL.lastPathComponent)")
        return true
    }


    // MARK: - Update Drop Target
    func updateDropTarget(targeted: Bool) {
        guard targeted else { return }
        let panelURL = appState.url(for: panelSide)
        dragDropManager.setDropTarget(panelURL)
    }
}
