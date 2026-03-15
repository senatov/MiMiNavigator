    // DirectoryActionsHandler.swift
    // MiMiNavigator
    //
    // Created by Iakov Senatov on 04.02.2026.
    // Copyright © 2026 Senatov. All rights reserved.
    // Description: Handles DirectoryAction dispatching from context menu

    import AppKit
    import FileModelKit
    import FavoritesKit
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
                    openDirectoryInPlace(file, panel: panel, appState: appState)

                case .openInNewTab:
                    openDirectoryInNewTab(file, panel: panel, appState: appState)

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
                    activeDialog = .rename(file: file, panel: panel)

                case .getInfo:
                    GetInfoService.shared.showGetInfo(for: file.urlValue)

                // ── Batch-compatible actions (use all marked files) ──
                case .cut:
                    clipboard.cut(files: batchFiles, from: panel)

                case .copy:
                    clipboard.copy(files: batchFiles, from: panel)

                case .copyAsPathname:
                    let paths = batchFiles.map { $0.urlValue.path }
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(paths.joined(separator: "\n"), forType: .string)
                    log.info("[DirectoryActions] copied \(paths.count) pathname(s) to clipboard")

                case .paste:
                    Task {
                        await performPaste(to: panel, appState: appState)
                    }

                case .compress:
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

                case .delete:
                    activeDialog = .deleteConfirmation(files: batchFiles)

                case .openOnOtherPanel:
                    openDirectoryOnOtherPanel(file, panel: panel, appState: appState)

                case .addToFavorites:
                    Task { @MainActor in
                        UserFavoritesStore.shared.add(url: file.urlValue)
                        log.info("[Favorites] directory added: \(file.urlValue.path)")
                    }
            }
        }

    // MARK: - Panel Navigation Helper
    /// Navigates a panel to a directory path and refreshes its file list.
    private func navigate(panel: PanelSide, to path: String, appState: AppState) async {
        appState.updatePath(path, for: panel)

        if panel == .left {
            await appState.scanner.setLeftDirectory(pathStr: path)
            await appState.scanner.refreshFiles(currSide: .left)
            await appState.refreshLeftFiles()
        } else {
            await appState.scanner.setRightDirectory(pathStr: path)
            await appState.scanner.refreshFiles(currSide: .right)
            await appState.refreshRightFiles()
        }
    }

        // MARK: - Open Directory in Place

        /// Opens a directory in the current tab (same as double-click behavior)
        func openDirectoryInPlace(_ file: CustomFile, panel: PanelSide, appState: AppState) {
            let resolvedURL = file.urlValue.resolvingSymlinksInPath()
            let targetPath = resolvedURL.path

            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: targetPath, isDirectory: &isDir), isDir.boolValue else {
                log.warning("[OpenDir] path not a valid directory: '\(targetPath)'")
                return
            }

            log.info("[OpenDir] entering directory: '\(file.nameStr)' panel=\(panel)")
        Task { @MainActor in
            await navigate(panel: panel, to: targetPath, appState: appState)
        }
        }

        // MARK: - Open in New Tab

        /// Opens a directory in a new tab on the same panel
        func openDirectoryInNewTab(_ file: CustomFile, panel: PanelSide, appState: AppState) {
            let resolvedURL = file.urlValue.resolvingSymlinksInPath()
            let targetPath = resolvedURL.path

            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: targetPath, isDirectory: &isDir), isDir.boolValue else {
                log.warning("[OpenInNewTab] path not a valid directory: '\(targetPath)'")
                return
            }

            let mgr = appState.tabManager(for: panel)
            let newTab = mgr.addTab(url: resolvedURL)
            log.info("[OpenInNewTab] directory tab added: '\(newTab.displayName)' panel=\(panel)")

        Task { @MainActor in
            await navigate(panel: panel, to: targetPath, appState: appState)
        }
        }

        /// Opens a file's containing directory (or archive as directory) in a new tab
        func openFileInNewTab(_ file: CustomFile, panel: PanelSide, appState: AppState) {
            // Archive files — open archive as virtual directory in new tab
            if file.isArchiveFile {
                log.info("[OpenInNewTab] opening archive in new tab: '\(file.nameStr)'")
                let mgr = appState.tabManager(for: panel)

                Task { @MainActor in
                    do {
                        let tempDir = try await ArchiveManager.shared.openArchive(at: file.urlValue)
                        let newTab = mgr.addTab(
                            url: tempDir,
                            archiveURL: file.urlValue
                        )
                        log.info("[OpenInNewTab] archive tab added: '\(newTab.displayName)' panel=\(panel)")

                        // Set archive navigation state
                        var archState = appState.archiveState(for: panel)
                        archState.enterArchive(archiveURL: file.urlValue, tempDir: tempDir)
                        appState.setArchiveState(archState, for: panel)

                    await navigate(panel: panel, to: tempDir.path, appState: appState)
                    } catch {
                        log.error("[OpenInNewTab] failed to open archive: \(error.localizedDescription)")
                    }
                }
                return
            }

            // Regular files — open containing directory in new tab
            let containingDirURL = file.urlValue.deletingLastPathComponent()
            log.info("[OpenInNewTab] file's parent dir in new tab: '\(containingDirURL.path)' for file '\(file.nameStr)'")

            let mgr = appState.tabManager(for: panel)
            let newTab = mgr.addTab(url: containingDirURL)
            log.info("[OpenInNewTab] file parent tab added: '\(newTab.displayName)' panel=\(panel)")

        Task { @MainActor in
            await navigate(panel: panel, to: containingDirURL.path, appState: appState)
        }
        }

        // MARK: - Private Directory Helpers

        /// Shows directory in Finder
        func openInFinder(_ file: CustomFile) {
            log.debug("\(#function) file='\(file.nameStr)' path='\(file.pathStr)'")
            NSWorkspace.shared.activateFileViewerSelecting([file.urlValue])
        }

        // MARK: - Open Directory on Other Panel

        /// Opens a directory on the opposite panel
        func openDirectoryOnOtherPanel(_ file: CustomFile, panel: PanelSide, appState: AppState) {
            let resolvedURL = file.urlValue.resolvingSymlinksInPath()
            let targetPath = resolvedURL.path

            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: targetPath, isDirectory: &isDir), isDir.boolValue else {
                log.warning("[OpenOnOther] not a valid directory: '\(targetPath)'")
                return
            }

            let otherPanel: PanelSide = panel == .left ? .right : .left
            log.info("[OpenOnOther] dir='\(file.nameStr)' → panel=\(otherPanel)")
        Task { @MainActor in
            await navigate(panel: otherPanel, to: targetPath, appState: appState)
        }
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
