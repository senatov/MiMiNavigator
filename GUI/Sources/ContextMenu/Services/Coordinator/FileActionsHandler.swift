// FileActionsHandler.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 04.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Handles FileAction dispatching from context menu

import AppKit
import FavoritesKit
import FileModelKit
import Foundation

// MARK: - File Actions Handler
/// Extension handling FileAction dispatching
extension ContextMenuCoordinator {
    /// Handles file context menu actions.
    /// Batch-compatible actions (cut/copy/compress/pack/share/revealInFinder/delete)
    /// use filesForOperation() to include all marked files when present.
    /// Single-file actions (open/openWith/viewLister/rename/getInfo/duplicate/createLink)
    /// always operate on the clicked file only.
    func handleFileAction(_ action: FileAction, for file: CustomFile, panel: FavPanelSide, appState: AppState) {
        log.debug(#function + "(\(action), \(file), \(panel))")
        let batchFiles = appState.filesForOperation(on: panel)
        log.debug("[FileActions] action='\(action.rawValue)' file='\(file.nameStr)' path='\(file.urlValue.path)' batch=\(batchFiles.count) panel=\(panel)")

        switch action {
            // ── Single-file actions (always use clicked file) ──
            case .open:
                openFileOrArchive(file, panel: panel, appState: appState)
            case .browseContents:
                Task { @MainActor in
                    await navigate(panel: panel, to: file.urlValue.path, appState: appState)
                }

            case .openWith:
                // Handled by OpenWithSubmenu directly
                log.debug("\(#function) openWith handled by submenu")

            case .openInNewTab:
                openFileInNewTab(file, panel: panel, appState: appState)

            case .viewLister:
                openQuickLook(file)

            case .duplicate:
                performAsync { [weak self] in
                    guard let self = self else { return }
                    await self.performDuplicate(file: file, appState: appState)
                }

            case .createLink:
                let destination = getOppositeDestinationPath(for: panel, appState: appState)
                log.debug("\(#function) createLink destination='\(destination.path)'")
                activeDialog = .createLink(file: file, destination: destination)

            case .rename:
                activeDialog = .rename(file: file, panel: panel)

            case .getInfo:
                GetInfoService.shared.showGetInfo(for: file.urlValue)

            // ── Batch-compatible actions (use all marked files) ──
            case .cut:
                clipboard.cut(files: batchFiles, from: panel)

            case .copy:
                clipboard.copy(files: batchFiles, from: panel)

            case .copyAsPathname:
                copyPathsToPasteboard(batchFiles)

            case .paste:
                performAsync { [weak self] in
                    guard let self = self else { return }
                    await self.performPaste(to: panel, appState: appState)
                }
            case .compress:
                // Show PackDialog with source directory as default destination
                let sourceDir = file.urlValue.deletingLastPathComponent()
                log.debug("\(#function) compress → PackDialog destination='\(sourceDir.path)'")
                activeDialog = .pack(files: batchFiles, destination: sourceDir, sourcePanel: panel)

            case .pack:
                let destination = getOppositeDestinationPath(for: panel, appState: appState)
                log.debug("\(#function) pack destination='\(destination.path)'")
                activeDialog = .pack(files: batchFiles, destination: destination, sourcePanel: panel)

            case .share:
                let urls = batchFiles.map { $0.urlValue }
                ShareService.shared.showSharePicker(for: urls)

            case .revealInFinder:
                let urls = batchFiles.map { $0.urlValue }
                NSWorkspace.shared.activateFileViewerSelecting(urls)

            case .delete:
                activeDialog = .deleteConfirmation(files: batchFiles)

            case .addToFavorites:
                performAsyncMain {
                    let url = file.urlValue
                    UserFavoritesStore.shared.add(url: url)
                    log.info("[Favorites] file added: \(url.path)")
                }
        }
    }

    // MARK: - Panel Navigation Helper
    /// Navigates the given panel to a directory path and refreshes file list.
    @MainActor
    private func navigate(panel: FavPanelSide, to path: String, appState: AppState) async {
        log.debug(#function + "(\(path))")
        // Reset selection before navigation
        appState.selectedLeftFile = nil
        appState.selectedRightFile = nil
        // Update panel path
        appState.updatePath(path, for: panel)
        // Navigate and refresh
        switch panel {
            case .left:
                await appState.scanner.setLeftDirectory(pathStr: path)
                await appState.refreshFiles(for: .left, force: true)

            case .right:
                await appState.scanner.setRightDirectory(pathStr: path)
                await appState.refreshFiles(for: .right, force: true)
        }
    }

    // MARK: - Private File Helpers

    /// Opens file: archive files open as virtual directory (Total Commander style),
    /// regular files open with default application via NSWorkspace.
    func openFileOrArchive(_ file: CustomFile, panel: FavPanelSide, appState: AppState) {
        log.debug(#function + "(\(file.nameStr))")
        // Archive files — open as virtual directory in current tab (Total Commander behavior)
        if file.isArchiveFile {
            log.info("[FileActions] open archive: name='\(file.nameStr)' path='\(file.urlValue.path)'")
            Task { @MainActor in
                await appState.enterArchive(at: file.urlValue, on: panel)
            }
            return
        }

        // Regular files — open with system default application
        log.debug("[FileActions] open file via NSWorkspace: name='\(file.nameStr)' path='\(file.urlValue.path)'")
        NSWorkspace.shared.open(file.urlValue)
    }

    /// Opens file with default application (direct, no archive check)
    func openFile(_ file: CustomFile) {
        log.debug("\(#function) file='\(file.nameStr)' path='\(file.urlValue.path)'")
        NSWorkspace.shared.open(file.urlValue)
    }

    /// Opens Quick Look preview panel
    func openQuickLook(_ file: CustomFile) {
        log.debug("\(#function) file='\(file.nameStr)'")
        QuickLookService.shared.preview(file: file.urlValue)
    }
}

    // MARK: - Async Helpers

    private func performAsync(_ block: @escaping @Sendable () async -> Void) {
        Task.detached(priority: .userInitiated) {
            await block()
        }
    }

    private func performAsyncMain(_ block: @escaping @Sendable @MainActor () -> Void) {
        Task { @MainActor in
            block()
        }
    }

    // MARK: - Pasteboard

    private func copyPathsToPasteboard(_ files: [CustomFile]) {
        let paths = files.map { $0.urlValue.path }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(paths.joined(separator: "\n"), forType: .string)
        log.info("[FileActions] copied \(paths.count) pathname(s) to clipboard")
    }
