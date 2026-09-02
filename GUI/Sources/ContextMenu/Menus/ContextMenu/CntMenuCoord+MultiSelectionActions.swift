// CntMenuCoord+MultiSelectionActions.swift
// MiMiNavigator
//
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
            case .getInfo:
                GetInfoService.shared.showGetInfo(for: files.map(\.urlValue))
            case .compress:
                presentCompressDialog(for: files, panel: panel, appState: appState)
            case .share:
                share(files)
            case .revealInFinder:
                revealInFinder(files)
            case .console:
                openTerminal(at: getDestinationPath(for: panel, appState: appState))
            case .delete:
                activeDialog = .deleteConfirmation(files: files)
        }
    }





    func presentCompressDialog(for files: [CustomFile], panel: FavPanelSide, appState: AppState) {
        log.debug("\(#function) panel=\(panel) batch=\(files.count)")
        PackDialogCoordinator.shared.open(
            mode: .compress,
            files: files,
            sourcePanel: panel,
            appState: appState
        ) { [weak self] archiveName, format, destination, deleteSource, compressionLevel, password in
            guard let self else { return }
            Task {
                await self.performArchiveCreation(
                    files: files,
                    archiveName: archiveName,
                    format: format,
                    destination: destination,
                    deleteSource: deleteSource,
                    compressionLevel: compressionLevel,
                    password: password,
                    appState: appState
                )
            }
        }
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
