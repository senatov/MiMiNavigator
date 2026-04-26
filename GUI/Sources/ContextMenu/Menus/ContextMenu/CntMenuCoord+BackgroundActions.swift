// CntMenuCoord+BackgroundActions.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 04.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Handles PanelBackgroundAction dispatching from panel empty area context menu

import AppKit
import FavoritesKit
import FileModelKit
import Foundation

// MARK: - Panel Background Actions Handler
/// Extension handling PanelBackgroundAction dispatching
extension CntMenuCoord {

    /// Handles panel background context menu actions (right-click on empty area)
    func handlePanelBackgroundAction(_ action: PanelBackgroundAction, for panel: FavPanelSide, appState: AppState) {
        let currentPath = getDestinationPath(for: panel, appState: appState)
        log.debug("\(#function) action=\(action.rawValue) panel=\(panel) path='\(currentPath.path)'")
        switch action {
            case .goUp:
                navigateUp(from: currentPath, panel: panel, appState: appState)
            case .goBack:
                navigateHistoryBack(panel: panel, appState: appState)
            case .goForward:
                navigateHistoryForward(panel: panel, appState: appState)
            case .refresh:
                refreshPanel(panel, appState: appState)
            case .newFolder:
                performNewFolder(in: currentPath, appState: appState)
            case .newFile:
                performNewFile(in: currentPath, appState: appState)
            case .paste:
                performAsync { [weak self] in
                    guard let self = self else { return }
                    await self.performPaste(to: panel, appState: appState)
                }
            case .sortByName, .sortByDate, .sortBySize, .sortByType:
                log.info("\(#function) sort action '\(action.rawValue)' not yet implemented")
            case .openInFinder:
                RevealInFinderService.shared.revealInFinder(currentPath)
            case .openInTerminal, .console:
                openTerminal(at: currentPath)
            case .mirrorPath:
                mirrorPathToOtherPanel(panel, appState: appState)
            case .openMarkedOnOtherPanel:
                openFirstMarkedDirectoryOnOtherPanel(panel, appState: appState)
            case .getInfo:
                GetInfoService.shared.showGetInfo(for: currentPath)
            case .copyAsPathname:
                copyCurrentPathToPasteboard(currentPath)
            case .addToFavorites:
                addCurrentDirToFavorites(currentPath)
        }
    }

    func navigateUp(from currentPath: URL, panel: FavPanelSide, appState: AppState) {
        let parent = currentPath.deletingLastPathComponent()
        log.debug("\(#function) parent='\(parent.path)' panel=\(panel)")
        navigateTo(parent, panel: panel, appState: appState)
    }

    func navigateHistoryBack(panel: FavPanelSide, appState: AppState) {
        guard let path = appState.selectionsHistory.goBack() else {
            log.debug("\(#function) no history panel=\(panel)")
            return
        }
        Task { @MainActor in
            appState.isNavigatingFromHistory = true
            defer { appState.isNavigatingFromHistory = false }
            navigateTo(path, panel: panel, appState: appState)
        }
    }

    func navigateHistoryForward(panel: FavPanelSide, appState: AppState) {
        guard let path = appState.selectionsHistory.goForward() else {
            log.debug("\(#function) no history panel=\(panel)")
            return
        }
        Task { @MainActor in
            appState.isNavigatingFromHistory = true
            defer { appState.isNavigatingFromHistory = false }
            navigateTo(path, panel: panel, appState: appState)
        }
    }

    // MARK: - Navigation

    /// Navigate panel to specified path (with retry + spinner for slow volumes)
    func navigateTo(_ url: URL, panel: FavPanelSide, appState: AppState) {
        log.debug("\(#function) url='\(url.path)' panel=\(panel)")
        Task { @MainActor in
            await appState.navigateToDirectory(url.path, on: panel)
        }
    }

    /// Refresh single panel
    func refreshPanel(_ panel: FavPanelSide, appState: AppState) {
        log.debug("\(#function) panel=\(panel)")
        Task { @MainActor in
            await appState.scanner.refreshFiles(currSide: panel)
        }
    }

    // MARK: - Create Operations

    /// Determine which panel contains the given directory path
    func panelForPath(_ path: String, appState: AppState) -> FavPanelSide {
        if PathUtils.areEqual(appState.leftPath, path) { return .left }
        if PathUtils.areEqual(appState.rightPath, path) { return .right }
        return appState.focusedPanel
    }

    /// Show Create Folder dialog so the user can enter a name
    func performNewFolder(in directory: URL, appState: AppState) {
        log.debug("\(#function) showing dialog for directory='\(directory.path)'")
        activeDialog = .createFolder(parentURL: directory)
    }

    /// Create new empty file in directory, then select it
    func performNewFile(in directory: URL, appState: AppState) {
        log.debug("\(#function) directory='\(directory.path)'")

        // guard: reject remote / mangled paths
        guard !AppState.isRemotePath(directory) && directory.isFileURL else {
            log.error("\(#function) aborted — directory is remote: \(directory.absoluteString)")
            activeDialog = .error(
                title: "Create File Failed", message: "Can't create file in remote path: \(directory.lastPathComponent)")
            return
        }

        let newFileURL = generateUniqueName(baseName: "New File.txt", in: directory, isDirectory: false)

        do {
            try Data().write(to: newFileURL)
            let createdName = newFileURL.lastPathComponent
            let panel = panelForPath(directory.path, appState: appState)
            log.info("\(#function) ok — '\(createdName)' created, selecting on \(panel)")
            Task { @MainActor in
                await appState.refreshAndSelect(name: createdName, on: panel)
            }
        } catch {
            log.error("\(#function) FAILED: \(error.localizedDescription)")
            activeDialog = .error(title: "Create File Failed", message: error.localizedDescription)
        }
    }

    // MARK: - Cross-Panel Operations

    /// Mirror current panel's path to the opposite panel
    func mirrorPathToOtherPanel(_ panel: FavPanelSide, appState: AppState) {
        let currentPath = getDestinationPath(for: panel, appState: appState)
        let otherPanel: FavPanelSide = panel == .left ? .right : .left
        log.info("[MirrorPath] '\(currentPath.path)' → panel=\(otherPanel)")
        navigateTo(currentPath, panel: otherPanel, appState: appState)
    }

    /// Open the first marked directory on the opposite panel
    func openFirstMarkedDirectoryOnOtherPanel(_ panel: FavPanelSide, appState: AppState) {
        let markedDirs = appState.markedCustomFiles(for: panel).filter { $0.isDirectory }
        guard let firstDir = markedDirs.first else {
            log.warning("[OpenMarkedOnOther] no marked directories on \(panel)")
            return
        }

        let resolvedURL = firstDir.urlValue.resolvingSymlinksInPath()
        let targetPath = resolvedURL.path

        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: targetPath, isDirectory: &isDir), isDir.boolValue else {
            log.warning("[OpenMarkedOnOther] not a valid directory: '\(targetPath)'")
            return
        }

        let otherPanel: FavPanelSide = panel == .left ? .right : .left
        log.info("[OpenMarkedOnOther] dir='\(firstDir.nameStr)' → panel=\(otherPanel)")
        navigateTo(resolvedURL, panel: otherPanel, appState: appState)
    }

    // MARK: - Clipboard (Background)

    /// Copy current directory path to pasteboard
    private func copyCurrentPathToPasteboard(_ url: URL) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(url.path, forType: .string)
        log.info("[Background] copied path to clipboard: '\(url.path)'")
    }


    /// Add current directory to favorites
    private func addCurrentDirToFavorites(_ url: URL) {
        UserFavoritesStore.shared.add(url: url)
        log.info("[Favorites] background: added current dir '\(url.lastPathComponent)'")
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
