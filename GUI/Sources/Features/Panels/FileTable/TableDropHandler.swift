// TableDropHandler.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 27.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Drag and drop handling for FileTableView panel background

import FileModelKit
import SwiftUI

// MARK: - Table Drop Handler
/// Handles drag and drop operations on the panel background
@MainActor
struct TableDropHandler {
    let panelSide: PanelSide
    let appState: AppState
    let dragDropManager: DragDropManager

    /// Handle files dropped on panel background
    func handlePanelDrop(_ droppedFiles: [CustomFile]) -> Bool {
        log.debug("[DROP] handlePanelDrop called with \(droppedFiles.count) files")
        guard !droppedFiles.isEmpty else {
            log.debug("[TableDropHandler] drop ignored: empty")
            return false
        }
        let panelPath = panelSide == .left ? appState.leftPath : appState.rightPath
        let destinationURL = URL(fileURLWithPath: panelPath)
        // Determine source panel first
        let sourceSide: PanelSide? = panelSide == .left ? .right : .left
        // Prevent dropping onto same directory only if it originates from the same panel
        if let firstFile = droppedFiles.first {
            let sourceDir = firstFile.urlValue.deletingLastPathComponent()
            if sourceDir.path == destinationURL.path && sourceSide == panelSide {
                log.debug("[TableDropHandler] drop ignored: same directory (same panel)")
                return false
            }
        }
        log.debug("[DROP] destination = \(destinationURL.path)")
        dragDropManager.prepareTransfer(files: droppedFiles, to: destinationURL, from: sourceSide)
        log.info("[TableDropHandler] prepared transfer of \(droppedFiles.count) files to \(destinationURL.path)")
        return true
    }

    /// Update drop target when panel is targeted
    func updateDropTarget(targeted: Bool) {
        if targeted {
            let panelPath = panelSide == .left ? appState.leftPath : appState.rightPath
            dragDropManager.setDropTarget(URL(fileURLWithPath: panelPath))
            log.debug("[TableDropHandler] drop target set: \(panelPath)")
        }
    }
}
