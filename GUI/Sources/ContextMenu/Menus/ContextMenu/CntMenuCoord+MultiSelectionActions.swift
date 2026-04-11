// CntMenuCoord+MultiSelectionActions.swift
// MiMiNavigator
//
// Created by Claude on 14.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Handles MultiSelectionAction dispatching for batch operations

import AppKit
import FileModelKit
import Foundation

// MARK: - Multi Selection Actions Handler
/// Extension handling batch operations on multiple marked files
extension CntMenuCoord {

    /// Handles multi-selection context menu actions
    func handleMultiSelectionAction(_ action: MultiSelectionAction, panel: FavPanelSide, appState: AppState) {
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
            case .copyAsPathname:
                copyPathsToPasteboard(files)
            case .paste:
                performAsync { [weak self] in
                    guard let self = self else { return }
                    await self.performPaste(to: panel, appState: appState)
                }
            case .compress:
                presentCompressDialog(for: files, panel: panel, appState: appState)
            case .share:
                share(files)
            case .revealInFinder:
                revealInFinder(files)
            case .delete:
                activeDialog = .deleteConfirmation(files: files)
        }
    }





    func presentCompressDialog(for files: [CustomFile], panel: FavPanelSide, appState: AppState) {
        let destination = appState.url(for: panel == .left ? .right : .left)
        activeDialog = .compress(files: files, destination: destination, sourcePanel: panel)
    }



    func share(_ files: [CustomFile]) {
        let urls = files.map { $0.urlValue }
        ShareService.shared.showSharePicker(for: urls)
    }



    func revealInFinder(_ files: [CustomFile]) {
        let urls = files.map { $0.urlValue }
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }
}
