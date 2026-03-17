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

        // MARK: - F3 View
        func performView() {
            log.debug("performView — F3 pressed")
            guard let file = currentSelectedFile, !file.isDirectory else {
                log.debug("performView: no file selected or is directory")
                return
            }
            openWithDefaultOrPicker(file: file, preferEdit: false)
        }

        // MARK: - F4 Edit
        func performEdit() {
            log.debug("performEdit — F4 pressed")
            guard let file = currentSelectedFile, !file.isDirectory else {
                log.debug("performEdit: no file selected or is directory")
                return
            }
            openWithDefaultOrPicker(file: file, preferEdit: true)
        }

        // MARK: - Open with default app; if none — show Open With picker
        @MainActor
        private func openWithDefaultOrPicker(file: CustomFile, preferEdit: Bool) {
            let url = file.urlValue
            // Try default application from Launch Services
            if let defaultApp = NSWorkspace.shared.urlForApplication(toOpen: url) {
                log.info("Opening '\(file.nameStr)' with default app: \(defaultApp.lastPathComponent)")
                let config = NSWorkspace.OpenConfiguration()
                config.activates = true
                NSWorkspace.shared.open([url], withApplicationAt: defaultApp, configuration: config) { _, error in
                    if let error {
                        log.error("openWithDefault failed: \(error.localizedDescription)")
                    }
                }
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

        // MARK: - F5 Copy (supports batch operations)
        func performCopy() {
            log.debug("performCopy - Copy button pressed")

            // Use batch coordinator for multi-selection support
            BatchOperationCoordinator.shared.initiateCopy(appState: appState)
        }

        // MARK: - F6 Move (supports batch operations)
        func performMove() {
            log.debug("performMove - Move button pressed")

            // Use batch coordinator for multi-selection support
            BatchOperationCoordinator.shared.initiateMove(appState: appState)
        }

        // MARK: - F7 New Folder
        func performNewFolder() {
            log.debug("performNewFolder - New Folder button pressed")

            guard let currentURL = appState.pathURL(for: appState.focusedPanel) else {
                log.debug("No current directory for New Folder")
                return
            }

            // Show SwiftUI HIG-style dialog via coordinator (same style as Copy/Move/Pack)
            ContextMenuCoordinator.shared.activeDialog = .createFolder(parentURL: currentURL)
        }

        // MARK: - Delete (Fwd-Delete / F8) — Trash for real files, removeItem inside archives
        func performDelete() {
            log.debug("performDelete — moving to Trash")

            let panel = appState.focusedPanel
            let files = appState.filesForOperation(on: panel)

            guard !files.isEmpty else {
                log.warning("performDelete: nothing to delete")
                return
            }

            let urls = files
                .filter { !ParentDirectoryEntry.isParentEntry($0) }
                .map { $0.urlValue }

            guard !urls.isEmpty else { return }

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
                            let desc = error.localizedDescription
                            log.error("\(#function) archive rm bombed '\(url.lastPathComponent)' — \(desc)")
                            await MainActor.run { Self.showDeleteError(desc, urls: [url]) }
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
                // Normal filesystem: move to Trash via NSWorkspace
                // Run recycle off MainActor — it can take 10-15s in large directories
                log.info("performDelete: recycling \(urls.count) item(s): \(urls.map(\.lastPathComponent))")
                Task.detached(priority: .userInitiated) {
                    let (trashedURLs, error) = await withCheckedContinuation { cont in
                        NSWorkspace.shared.recycle(urls) { trashed, err in
                            cont.resume(returning: (trashed, err))
                        }
                    }
                    if let error {
                        let desc = error.localizedDescription
                        log.error("\(#function) recycle bombed — \(desc)")
                        await MainActor.run { Self.showDeleteError(desc, urls: urls) }
                        return
                    }
                    log.info("\(#function) trashed \(trashedURLs.count) item(s) ✓")
                    await self.appState.refreshAndSelectAfterRemoval(removedFiles: files, on: panel)
                }
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
            let path = appState.pathURL(for: appState.focusedPanel)?.path ?? "/"
            ConsoleCurrPath.open(in: path)
        }

        // MARK: - Exit
        func performExit() {
            log.debug("performExit - Exit button pressed")

            // Cleanup temporary JSON files in /tmp owned by current user
            cleanupUserTmpJSON()

            appState.saveBeforeExit()
            NSApplication.shared.terminate(nil)
        }

        // Remove *.json files in /tmp that belong to the current user
        private func cleanupUserTmpJSON() {
            let tmpURL = URL(fileURLWithPath: "/tmp", isDirectory: true)
            let fm = FileManager.default
            let currentUID = getuid()

            guard let enumerator = fm.enumerator(at: tmpURL, includingPropertiesForKeys: [.isRegularFileKey, .nameKey], options: [.skipsHiddenFiles]) else {
                log.warning("[TmpCleanup] failed to enumerate /tmp")
                return
            }

            var removed = 0

            for case let fileURL as URL in enumerator {
                guard fileURL.pathExtension.lowercased() == "json" else { continue }

                do {
                    let attrs = try fm.attributesOfItem(atPath: fileURL.path)
                    if let ownerID = attrs[.ownerAccountID] as? NSNumber,
                       ownerID.uint32Value == currentUID {
                        try fm.removeItem(at: fileURL)
                        removed += 1
                        log.debug("[TmpCleanup] removed \(fileURL.lastPathComponent)")
                    }
                } catch {
                    log.warning("[TmpCleanup] failed to remove \(fileURL.lastPathComponent): \(error.localizedDescription)")
                }
            }

            log.info("[TmpCleanup] removed \(removed) user JSON file(s) from /tmp")
        }

        // MARK: - Delete error alert
    /// pops NSAlert so user actually sees wtf went wrong (perms, gone file, etc.)
    @MainActor
    private static func showDeleteError(_ reason: String, urls: [URL]) {
        log.warning("\(#function) showing delete-fail alert for \(urls.count) item(s)")
        let names = urls.prefix(5).map(\.lastPathComponent).joined(separator: "\n  • ")
        let more = urls.count > 5 ? "\n  … and \(urls.count - 5) more" : ""

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Can't Move to Trash"
        alert.informativeText = """
            Failed to delete:
              • \(names)\(more)

            Reason: \(reason)

            Tip: system/temp files owned by root can't be trashed from sandbox.
            """
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    // MARK: - Computed Properties

        private var currentSelectedFile: CustomFile? {
            appState.focusedPanel == .left ? appState.selectedLeftFile : appState.selectedRightFile
        }

        private var targetPanelURL: URL? {
            let targetSide: PanelSide = appState.focusedPanel == .left ? .right : .left
            return appState.pathURL(for: targetSide)
        }
    }
