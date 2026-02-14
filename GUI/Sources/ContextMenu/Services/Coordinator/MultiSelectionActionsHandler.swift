// MultiSelectionActionsHandler.swift
// MiMiNavigator
//
// Created by Claude on 14.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Handles MultiSelectionAction dispatching for batch operations

import AppKit
import Foundation

// MARK: - Multi Selection Actions Handler
/// Extension handling batch operations on multiple marked files
extension ContextMenuCoordinator {

    /// Handles multi-selection context menu actions
    func handleMultiSelectionAction(_ action: MultiSelectionAction, panel: PanelSide, appState: AppState) {
        let files = appState.filesForOperation(on: panel)

        guard !files.isEmpty else {
            log.warning("[MultiSelectionActionsHandler] no files for operation")
            return
        }

        log.debug("[MultiSelectionActionsHandler] action=\(action.rawValue) files.count=\(files.count) panel=\(panel)")

        switch action {
        case .cut:
            clipboard.cut(files: files, from: panel)
            log.info("[MultiSelectionActionsHandler] cut \(files.count) files")

        case .copy:
            clipboard.copy(files: files, from: panel)
            log.info("[MultiSelectionActionsHandler] copied \(files.count) files")

        case .paste:
            Task {
                await performPaste(to: panel, appState: appState)
            }

        case .compress:
            Task {
                await performCompress(files: files, appState: appState)
                appState.clearMarksAfterOperation(on: panel)
            }

        case .share:
            let urls = files.map { $0.urlValue }
            ShareService.shared.showSharePicker(for: urls)

        case .revealInFinder:
            let urls = files.map { $0.urlValue }
            NSWorkspace.shared.activateFileViewerSelecting(urls)

        case .delete:
            activeDialog = .deleteConfirmation(files: files)
        }
    }
}
