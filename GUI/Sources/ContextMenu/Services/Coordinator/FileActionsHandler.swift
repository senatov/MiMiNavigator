// FileActionsHandler.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 04.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Handles FileAction dispatching from context menu

import AppKit
import FileModelKit
import FavoritesKit
import Foundation

// MARK: - File Actions Handler
/// Extension handling FileAction dispatching
extension ContextMenuCoordinator {

    /// Handles file context menu actions.
    /// Batch-compatible actions (cut/copy/compress/pack/share/revealInFinder/delete)
    /// use filesForOperation() to include all marked files when present.
    /// Single-file actions (open/openWith/viewLister/rename/getInfo/duplicate/createLink)
    /// always operate on the clicked file only.
    func handleFileAction(_ action: FileAction, for file: CustomFile, panel: PanelSide, appState: AppState) {
        // For batch-compatible actions, use marked files if any, otherwise single file
        let batchFiles = appState.filesForOperation(on: panel)
        log.debug("\(#function) action=\(action.rawValue) file='\(file.nameStr)' panel=\(panel) batchCount=\(batchFiles.count)")

        switch action {
            // ── Single-file actions (always use clicked file) ──
            case .open:
                openFileOrArchive(file, panel: panel, appState: appState)

            case .openWith:
                // Handled by OpenWithSubmenu directly
                log.debug("\(#function) openWith handled by submenu")

            case .openInNewTab:
                openFileInNewTab(file, panel: panel, appState: appState)

            case .viewLister:
                openQuickLook(file)

            case .duplicate:
                Task {
                    await performDuplicate(file: file, appState: appState)
                }

            case .createLink:
                let destination = getOppositeDestinationPath(for: panel, appState: appState)
                log.debug("\(#function) createLink destination='\(destination.path)'")
                activeDialog = .createLink(file: file, destination: destination)

            case .rename:
                activeDialog = .rename(file: file)

            case .getInfo:
                GetInfoService.shared.showGetInfo(for: file.urlValue)

            // ── Batch-compatible actions (use all marked files) ──
            case .cut:
                clipboard.cut(files: batchFiles, from: panel)

            case .copy:
                clipboard.copy(files: batchFiles, from: panel)

            case .paste:
                Task {
                    await performPaste(to: panel, appState: appState)
                }

            case .compress:
                // Show PackDialog with source directory as default destination
                let sourceDir = file.urlValue.deletingLastPathComponent()
                log.debug("\(#function) compress → PackDialog destination='\(sourceDir.path)'")
                activeDialog = .pack(files: batchFiles, destination: sourceDir)

            case .pack:
                let destination = getOppositeDestinationPath(for: panel, appState: appState)
                log.debug("\(#function) pack destination='\(destination.path)'")
                activeDialog = .pack(files: batchFiles, destination: destination)

            case .share:
                let urls = batchFiles.map { $0.urlValue }
                ShareService.shared.showSharePicker(for: urls)

            case .revealInFinder:
                let urls = batchFiles.map { $0.urlValue }
                NSWorkspace.shared.activateFileViewerSelecting(urls)

            case .delete:
                activeDialog = .deleteConfirmation(files: batchFiles)

            case .addToFavorites:
                Task { @MainActor in
                    UserFavoritesStore.shared.add(path: file.pathStr)
                    log.info("[Favorites] file added: \(file.pathStr)")
                }
        }
    }

    // MARK: - Private File Helpers

    /// Opens file: archive files open as virtual directory (Total Commander style),
    /// regular files open with default application via NSWorkspace.
    func openFileOrArchive(_ file: CustomFile, panel: PanelSide, appState: AppState) {
        // Archive files — open as virtual directory in current tab (Total Commander behavior)
        if file.isArchiveFile {
            log.info("[FileActions] opening archive as virtual dir: '\(file.nameStr)'")
            Task { @MainActor in
                await appState.enterArchive(at: file.urlValue, on: panel)
            }
            return
        }

        // Regular files — open with system default application
        log.debug("[FileActions] openFile via NSWorkspace: '\(file.nameStr)'")
        NSWorkspace.shared.open(file.urlValue)
    }

    /// Opens file with default application (direct, no archive check)
    func openFile(_ file: CustomFile) {
        log.debug("\(#function) file='\(file.nameStr)' path='\(file.pathStr)'")
        NSWorkspace.shared.open(file.urlValue)
    }

    /// Opens Quick Look preview panel
    func openQuickLook(_ file: CustomFile) {
        log.debug("\(#function) file='\(file.nameStr)'")
        QuickLookService.shared.preview(file: file.urlValue)
    }
}
