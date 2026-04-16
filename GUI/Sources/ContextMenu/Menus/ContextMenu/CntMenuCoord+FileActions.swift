// CntMenuCoord+FileActions.swift
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
extension CntMenuCoord {
    /// Handles file context menu actions.
    /// Batch-compatible actions (cut/copy/compress/pack/share/revealInFinder/delete)
    /// use filesForOperation() to include all marked files when present.
    /// Single-file actions (open/openWith/viewLister/rename/getInfo/duplicate/createLink)
    /// always operate on the clicked file only.
    func handleFileAction(_ action: FileAction, for file: CustomFile, panel: FavPanelSide, appState: AppState) {
        log.debug(#function + "(\(action), \(file), \(panel))")
        let batchFiles = appState.filesForOperation(on: panel)
        log.debug(
            "[FileActions] action='\(action.rawValue)' file='\(file.nameStr)' path='\(file.urlValue.path)' batch=\(batchFiles.count) panel=\(panel)"
        )
        switch action {
            case .open:
                openFileOrArchive(file, panel: panel, appState: appState)
            case .browseContents:
                Task { @MainActor in
                    await navigate(panel: panel, to: file.urlValue.path, appState: appState)
                }
            case .openWith:
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
                presentCreateLinkDialog(for: file, panel: panel, appState: appState)
            case .rename:
                activeDialog = .rename(file: file, panel: panel)
            case .getInfo:
                GetInfoService.shared.showGetInfo(for: file.urlValue)
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
                presentCompressDialog(for: file, batchFiles: batchFiles, panel: panel, appState: appState)
            case .pack:
                presentPackDialog(for: batchFiles, panel: panel, appState: appState)
            case .share:
                share(batchFiles)
            case .convertMedia:
                ConvertMediaCoord.shared.open(file: file, panel: panel, appState: appState)
            case .revealInFinder:
                revealInFinder(batchFiles)
            case .delete:
                activeDialog = .deleteConfirmation(files: batchFiles)
            case .addToFavorites:
                addParentToFavorites(file)
            case .mirrorPanel:
                mirrorPathToOtherPanel(panel, appState: appState)
            case .newFolder:
                let dir = getDestinationPath(for: panel, appState: appState)
                performNewFolder(in: dir, appState: appState)
            case .newFile:
                let dir = getDestinationPath(for: panel, appState: appState)
                performNewFile(in: dir, appState: appState)
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
    private func openFileOrArchive(_ file: CustomFile, panel: FavPanelSide, appState: AppState) {
        log.debug(#function + "(\(file.nameStr))")
        // Browsable archive files — open as virtual directory (Total Commander behavior)
        // Opaque archives (dmg, pkg, iso, jar…) fall through to NSWorkspace.open
        if file.isBrowsableArchive {
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

    private func presentCreateLinkDialog(for file: CustomFile, panel: FavPanelSide, appState: AppState) {
        let destination = getOppositeDestinationPath(for: panel, appState: appState)
        log.debug("\(#function) destination='\(destination.path)'")
        activeDialog = .createLink(file: file, destination: destination)
    }

    private func presentCompressDialog(for file: CustomFile, batchFiles: [CustomFile], panel: FavPanelSide, appState: AppState) {
        log.debug("\(#function) panel=\(panel) batch=\(batchFiles.count)")
        PackDialogCoordinator.shared.open(
            mode: .compress,
            files: batchFiles,
            sourcePanel: panel,
            appState: appState
        ) { [weak self] archiveName, format, destination, deleteSource, compressionLevel, password in
            guard let self else { return }
            Task {
                await self.performArchiveCreation(
                    files: batchFiles,
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


    private func presentPackDialog(for batchFiles: [CustomFile], panel: FavPanelSide, appState: AppState) {
        log.debug("\(#function) panel=\(panel) batch=\(batchFiles.count)")
        PackDialogCoordinator.shared.open(
            mode: .pack,
            files: batchFiles,
            sourcePanel: panel,
            appState: appState
        ) { [weak self] archiveName, format, destination, deleteSource, compressionLevel, password in
            guard let self else { return }
            Task {
                await self.performPack(
                    files: batchFiles,
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

    /// For files: add parent directory to favorites, not the file itself
    private func addParentToFavorites(_ file: CustomFile) {
        performAsyncMain {
            let dirURL = file.urlValue.deletingLastPathComponent()
            UserFavoritesStore.shared.add(url: dirURL)
            log.info("[Favorites] parent dir added for file '\(file.nameStr)': \(dirURL.path)")
        }
    }

    func openQuickLook(_ file: CustomFile) {
        log.debug("\(#function) file='\(file.nameStr)'")
        QuickLookService.shared.preview(file: file.urlValue)
    }

    // MARK: - Async Helpers
    func performAsync(_ block: @escaping @Sendable () async -> Void) {
        Task.detached(priority: .userInitiated) {
            await block()
        }
    }

    func performAsyncMain(_ block: @escaping @Sendable @MainActor () -> Void) {
        Task { @MainActor in
            block()
        }
    }

    // MARK: - Pasteboard
    func copyPathsToPasteboard(_ files: [CustomFile]) {
        let paths = files.map { $0.urlValue.path }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(paths.joined(separator: "\n"), forType: .string)
        log.info("[FileActions] copied \(paths.count) pathname(s) to clipboard")
    }
}
