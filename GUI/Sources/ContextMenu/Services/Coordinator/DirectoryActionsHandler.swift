// DirectoryActionsHandler.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 04.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Handles DirectoryAction dispatching from context menu

import AppKit
import Foundation

// MARK: - Directory Actions Handler
/// Extension handling DirectoryAction dispatching
extension ContextMenuCoordinator {

    /// Handles directory context menu actions.
    /// Batch-compatible actions (cut/copy/compress/pack/share/delete)
    /// use filesForOperation() to include all marked files when present.
    /// Single-file actions (open/openInNewTab/openInFinder/openInTerminal/viewLister/
    /// rename/getInfo/duplicate/createLink) always operate on the clicked directory only.
    func handleDirectoryAction(_ action: DirectoryAction, for file: CustomFile, panel: PanelSide, appState: AppState) {
        // For batch-compatible actions, use marked files if any, otherwise single file
        let batchFiles = appState.filesForOperation(on: panel)
        log.debug("\(#function) action=\(action.rawValue) dir='\(file.nameStr)' panel=\(panel) batchCount=\(batchFiles.count)")

        switch action {
            // ── Single-file actions (always use clicked directory) ──
            case .open:
                // Handled by double-click in FilePanelView
                log.debug("\(#function) open handled by FilePanelView")

            case .openInNewTab:
                // TODO: Implement tab support
                log.info("\(#function) openInNewTab not yet implemented for '\(file.pathStr)'")

            case .openInFinder:
                openInFinder(file)

            case .openInTerminal:
                openInTerminal(file)

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
                Task {
                    await performCompress(files: batchFiles, appState: appState)
                    appState.clearMarksAfterOperation(on: panel)
                }

            case .pack:
                let destination = getOppositeDestinationPath(for: panel, appState: appState)
                log.debug("\(#function) pack destination='\(destination.path)'")
                activeDialog = .pack(files: batchFiles, destination: destination)

            case .share:
                let urls = batchFiles.map { $0.urlValue }
                ShareService.shared.showSharePicker(for: urls)

            case .delete:
                activeDialog = .deleteConfirmation(files: batchFiles)
        }
    }

    // MARK: - Private Directory Helpers

    /// Shows directory in Finder
    func openInFinder(_ file: CustomFile) {
        log.debug("\(#function) file='\(file.nameStr)' path='\(file.pathStr)'")
        NSWorkspace.shared.activateFileViewerSelecting([file.urlValue])
    }

    /// Opens Terminal at directory path
    func openInTerminal(_ file: CustomFile) {
        let path = file.isDirectory ? file.urlValue.path : file.urlValue.deletingLastPathComponent().path
        log.debug("\(#function) path='\(path)'")

        let script = """
            tell application "Terminal"
                activate
                do script "cd '\(path.replacingOccurrences(of: "'", with: "'\\''"))'"
            end tell
            """

        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
            if let error = error {
                log.error("\(#function) AppleScript FAILED: \(error)")
            } else {
                log.debug("\(#function) Terminal opened")
            }
        }
    }
}
