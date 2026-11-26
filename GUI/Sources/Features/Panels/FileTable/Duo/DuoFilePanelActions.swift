    // DuoFilePanelActions.swift
    // MiMiNavigator
    //
    // Created by Iakov Senatov on 27.01.2026.
    // Copyright © 2026 Senatov. All rights reserved.
    // Description: File operation actions for the dual-panel view

    import AppKit
    import FileModelKit
    import Foundation

    /// File operation actions performed from DuoFilePanelView
    /// Extracted to separate concerns from the main view
    @MainActor
    struct DuoFilePanelActions {
        let appState: AppState
        let refreshBothPanels: @concurrent @Sendable () async -> Void

        // MARK: - F3 Temp-Backup
        func performBackup() {
            let panel = appState.focusedPanel
            let files = appState.filesForOperation(on: panel).filter { !$0.isParentEntry }
            guard !files.isEmpty else {
                log.debug("[Backup] no files selected")
                return
            }
            Task { await CntMenuCoord.shared.requestBackup(files: files, sourcePanel: panel, appState: appState) }
        }

        // MARK: - F4 Edit
        func performEdit() {
            log.debug("performEdit — F4 pressed")
            guard let file = currentSelectedFile, !file.isDirectory else {
                log.debug("performEdit: no file selected or is directory")
                return
            }
            openWithDefaultApplication(file: file)
        }

        // MARK: - Open with default app; if none — show Open With picker
        @MainActor
        private func openWithDefaultApplication(file: CustomFile) {
            let url = file.urlValue
            // Try default application from Launch Services
            if let defaultApp = NSWorkspace.shared.urlForApplication(toOpen: url) {
                log.info("Opening '\(file.nameStr)' with default app: \(defaultApp.lastPathComponent)")
                ExternalApplicationLauncher.shared.open(
                    fileURL: url,
                    applicationURL: defaultApp,
                    bundleIdentifier: Bundle(url: defaultApp)?.bundleIdentifier
                )
                // Record in LRU
                if let bundleID = Bundle(url: defaultApp)?.bundleIdentifier {
                    OpenWithService.shared.recordUsage(bundleID: bundleID, ext: url.pathExtension, appURL: defaultApp)
                }
                return
            }
            // No default app — show OpenWith picker (same as "Other..." in context menu)
            log.info("No default app for '\(file.nameStr)' — showing Open With picker")
            OpenWithService.shared.showOpenWithPicker(for: url)
        }

        // MARK: - F2 Rename
        func performRename() {
            log.debug("[Rename] performRename - inline rename requested")
            let panel = appState.focusedPanel
            guard let file = currentSelectedFile, !file.isParentEntry, file.nameStr != ".." else { return }
            appState.inlineRename.begin(
                fileID: AnyHashable(file.id),
                fileName: file.nameStr,
                panelTag: panel == .left ? 0 : 1
            )
        }

        // MARK: - F5 Copy (supports batch operations)
        func performCopy() {
            log.debug("performCopy - Copy button pressed")

            // Use batch coordinator for multi-selection support
            BatchOpsCoord.shared.initiateCopy(appState: appState)
        }

        // MARK: - F6 Move (supports batch operations)
        func performMove() {
            log.debug("performMove - Move button pressed")

            // Use batch coordinator for multi-selection support
            BatchOpsCoord.shared.initiateMove(appState: appState)
        }

        // MARK: - F7 New Folder
        func performNewFolder() {
            log.debug("performNewFolder - New Folder button pressed")

            guard let currentURL = appState.pathURL(for: appState.focusedPanel) else {
                log.debug("No current directory for New Folder")
                return
            }

            // Show SwiftUI HIG-style dialog via coordinator (same style as Copy/Move/Pack)
            CntMenuCoord.shared.activeDialog = .createFolder(parentURL: currentURL)
        }

        // MARK: - Delete (Fwd-Delete / F8) — Trash for real files, removeItem inside archives
        func performDelete() {
            log.debug("[DELETE] ⏱ START performDelete")

            let panel = appState.focusedPanel
            let files = appState.filesForOperation(on: panel)
            log.debug("[DELETE] panel=\(panel), filesForOperation count=\(files.count)")

            guard !files.isEmpty else {
                log.warning("[DELETE] nothing to delete — filesForOperation returned empty")
                return
            }

            let urls = files
                .filter { !ParentDirectoryEntry.isParentEntry($0) }
                .map { $0.urlValue }
            
            log.debug("[DELETE] after filtering parent entries: \(urls.count) URLs to delete")

            guard !urls.isEmpty else {
                log.warning("[DELETE] all files were parent entries, nothing to delete")
                return
            }

            // Detect if we are inside an extracted archive temp dir
            let isInsideArchive = appState.archiveState(for: panel).isInsideArchive

            if isInsideArchive {
                // Inside archive: delete from temp dir + mark session dirty
                Task { @MainActor in
                    let fm = FileManager.default
                    var deletedCount = 0
                    for url in urls {
                        do {
                            try fm.removeItem(at: url)
                            deletedCount += 1
                            log.debug("\(#function) zapped archive tmp: \(url.lastPathComponent)")
                        } catch {
                            let diagnostic = FileOperationDiagnostics.makeDelete(source: url, error: error)
                            log.error("\(#function) archive rm bombed '\(url.lastPathComponent)' — \(diagnostic.details)")
                            FileOperationDiagnosticPresenter.shared.show(diagnostic)
                        }
                    }
                    if deletedCount > 0 {
                        // Mark archive dirty so it gets repacked on exit
                        if let archiveURL = self.appState.archiveState(for: panel).archiveURL {
                            await ArchiveManager.shared.markDirty(archivePath: archiveURL.path)
                        }
                        log.info("performDelete: removed \(deletedCount) item(s) from archive, marked dirty")
                        await self.appState.refreshAndSelectAfterRemoval(removedFiles: files, on: panel)
                    }
                }
            } else {
                BatchOpsCoord.shared.initiateDelete(appState: appState)
            }
        }

        // MARK: - F9 Settings
        func performSettings() {
            log.debug("performSettings — opening Settings window")
            SettingsCoordinator.shared.toggle()
        }

        // MARK: - Console
        func performConsole() {
            log.debug("performConsole - Console button pressed")
            let dir = appState.pathURL(for: appState.focusedPanel)?.path ?? "/"
            let escaped = dir.replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
            let src = """
                tell application "Terminal"
                    launch
                    activate
                    do script "cd \\\"\(escaped)\\\" && clear"
                end tell
                """
            var err: NSDictionary?
            NSAppleScript(source: src)?.executeAndReturnError(&err)
            if let err { log.error("[Console] AppleScript err: \(err)") }
        }

        // MARK: - Exit
        func performExit() {
            log.debug("[Exit] button pressed")
            NSApplication.shared.terminate(nil)
        }

    // MARK: - Computed Properties

        private var currentSelectedFile: CustomFile? {
            appState.focusedPanel == .left ? appState.selectedLeftFile : appState.selectedRightFile
        }
    }
