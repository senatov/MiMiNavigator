// PanelBackgroundActionsHandler.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 04.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Handles PanelBackgroundAction dispatching from panel empty area context menu

import AppKit
import Foundation

// MARK: - Panel Background Actions Handler
/// Extension handling PanelBackgroundAction dispatching
extension ContextMenuCoordinator {

    /// Handles panel background context menu actions (right-click on empty area)
    func handlePanelBackgroundAction(_ action: PanelBackgroundAction, for panel: PanelSide, appState: AppState) {
        let currentPath = getDestinationPath(for: panel, appState: appState)
        log.debug("\(#function) action=\(action.rawValue) panel=\(panel) path='\(currentPath.path)'")

        switch action {
            case .goUp:
                let parent = currentPath.deletingLastPathComponent()
                log.debug("\(#function) goUp to '\(parent.path)'")
                navigateTo(parent, panel: panel, appState: appState)

            case .goBack:
                guard let path = appState.selectionsHistory.goBack() else {
                    log.debug("\(#function) goBack: no history")
                    return
                }
                Task { @MainActor in
                    appState.isNavigatingFromHistory = true
                    defer { appState.isNavigatingFromHistory = false }
                    navigateTo(URL(fileURLWithPath: path), panel: panel, appState: appState)
                }

            case .goForward:
                guard let path = appState.selectionsHistory.goForward() else {
                    log.debug("\(#function) goForward: no history")
                    return
                }
                Task { @MainActor in
                    appState.isNavigatingFromHistory = true
                    defer { appState.isNavigatingFromHistory = false }
                    navigateTo(URL(fileURLWithPath: path), panel: panel, appState: appState)
                }

            case .refresh:
                refreshPanel(panel, appState: appState)

            case .newFolder:
                performNewFolder(in: currentPath, appState: appState)

            case .newFile:
                performNewFile(in: currentPath, appState: appState)

            case .paste:
                Task {
                    await performPaste(to: panel, appState: appState)
                }

            case .sortByName, .sortByDate, .sortBySize, .sortByType:
                // TODO: Implement sorting change
                log.info("\(#function) sort action '\(action.rawValue)' not yet implemented")

            case .openInFinder:
                RevealInFinderService.shared.revealInFinder(currentPath)

            case .openInTerminal:
                openTerminal(at: currentPath)

            case .getInfo:
                GetInfoService.shared.showGetInfo(for: currentPath)
        }
    }

    // MARK: - Navigation

    /// Navigate panel to specified path
    func navigateTo(_ url: URL, panel: PanelSide, appState: AppState) {
        log.debug("\(#function) url='\(url.path)' panel=\(panel)")
        Task { @MainActor in
            appState.updatePath(url.path, for: panel)
            if panel == .left {
                await appState.scanner.setLeftDirectory(pathStr: url.path)
                await appState.scanner.refreshFiles(currSide: .left)
            } else {
                await appState.scanner.setRightDirectory(pathStr: url.path)
                await appState.scanner.refreshFiles(currSide: .right)
            }
            log.debug("\(#function) navigation completed")
        }
    }

    /// Refresh single panel
    func refreshPanel(_ panel: PanelSide, appState: AppState) {
        log.debug("\(#function) panel=\(panel)")
        Task { @MainActor in
            await appState.scanner.refreshFiles(currSide: panel)
        }
    }

    // MARK: - Create Operations

    /// Create new folder in directory
    func performNewFolder(in directory: URL, appState: AppState) {
        log.debug("\(#function) directory='\(directory.path)'")

        let baseName = "New Folder"
        let newFolderURL = generateUniqueName(baseName: baseName, in: directory, isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: newFolderURL, withIntermediateDirectories: false)
            log.info("\(#function) SUCCESS created folder '\(newFolderURL.lastPathComponent)'")
            refreshPanels(appState: appState)
        } catch {
            log.error("\(#function) FAILED: \(error.localizedDescription)")
            activeDialog = .error(title: "Create Folder Failed", message: error.localizedDescription)
        }
    }

    /// Create new empty file in directory
    func performNewFile(in directory: URL, appState: AppState) {
        log.debug("\(#function) directory='\(directory.path)'")

        let baseName = "New File.txt"
        let newFileURL = generateUniqueName(baseName: baseName, in: directory, isDirectory: false)

        do {
            try Data().write(to: newFileURL)
            log.info("\(#function) SUCCESS created file '\(newFileURL.lastPathComponent)'")
            refreshPanels(appState: appState)
        } catch {
            log.error("\(#function) FAILED: \(error.localizedDescription)")
            activeDialog = .error(title: "Create File Failed", message: error.localizedDescription)
        }
    }

    // MARK: - Terminal

    /// Open Terminal at specified path
    func openTerminal(at url: URL) {
        log.debug("\(#function) path='\(url.path)'")

        let path = url.path
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
