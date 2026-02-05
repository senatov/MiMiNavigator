// DirectoryActionsHandler.swift
// MiMiNavigator
//
// Created by Claude AI on 04.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Handles DirectoryAction dispatching from context menu

import AppKit
import Foundation

// MARK: - Directory Actions Handler
/// Extension handling DirectoryAction dispatching
extension ContextMenuCoordinator {

    /// Handles directory context menu actions
    func handleDirectoryAction(_ action: DirectoryAction, for file: CustomFile, panel: PanelSide, appState: AppState) {
        log.debug("\(#function) action=\(action.rawValue) dir='\(file.nameStr)' panel=\(panel)")

        switch action {
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

            case .cut:
                clipboard.cut(files: [file], from: panel)

            case .copy:
                clipboard.copy(files: [file], from: panel)

            case .paste:
                Task {
                    await performPaste(to: panel, appState: appState)
                }

            case .duplicate:
                Task {
                    await performDuplicate(file: file, appState: appState)
                }

            case .compress:
                Task {
                    await performCompress(files: [file], appState: appState)
                }

            case .pack:
                let destination = getOppositeDestinationPath(for: panel, appState: appState)
                log.debug("\(#function) pack destination='\(destination.path)'")
                activeDialog = .pack(files: [file], destination: destination)

            case .createLink:
                let destination = getOppositeDestinationPath(for: panel, appState: appState)
                log.debug("\(#function) createLink destination='\(destination.path)'")
                activeDialog = .createLink(file: file, destination: destination)

            case .share:
                ShareService.shared.showSharePicker(for: [file.urlValue])

            case .rename:
                activeDialog = .rename(file: file)

            case .delete:
                activeDialog = .deleteConfirmation(files: [file])

            case .getInfo:
                GetInfoService.shared.showGetInfo(for: file.urlValue)

            case .properties:
                activeDialog = .properties(file: file)
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
