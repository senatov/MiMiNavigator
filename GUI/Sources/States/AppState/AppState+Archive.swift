// AppState+Archive.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 11.03.2026.
// Copyright © 2025-2026 Senatov. All rights reserved.
// Description: Archive enter/exit, password dialogs, repack confirmation

import AppKit
import FileModelKit
import Foundation

// MARK: - Archive Navigation
extension AppState {

    /// Navigate into an archive: extract to temp dir and open as directory
    func enterArchive(at archiveURL: URL, on panel: PanelSide, password: String? = nil) async {
        log.info("[AppState] Entering archive: \(archiveURL.lastPathComponent) panel=\(panel) hasPassword=\(password != nil)")
        ArchiveProgressPanel.shared.show(
            archiveName: archiveURL.lastPathComponent,
            destinationPath: archiveURL.deletingLastPathComponent().path
        )
        do {
            let tempDir = try await ArchiveManager.shared.openArchive(at: archiveURL, password: password)
            ArchiveProgressPanel.shared.hide()

            var state = archiveState(for: panel)
            state.enterArchive(archiveURL: archiveURL, tempDir: tempDir)
            setArchiveState(state, for: panel)

            tabManager(for: panel).updateActiveTabForArchive(extractedPath: tempDir.path, archiveURL: archiveURL)

            updatePath(tempDir.path, for: panel)
            if panel == .left {
                await scanner.setLeftDirectory(pathStr: tempDir.path)
                await refreshLeftFiles()
            } else {
                await scanner.setRightDirectory(pathStr: tempDir.path)
                await refreshRightFiles()
            }

            log.info("[AppState] Successfully entered archive: \(archiveURL.lastPathComponent)")
        } catch {
            ArchiveProgressPanel.shared.hide()
            log.error("[AppState] Failed to enter archive: \(error.localizedDescription)")
            await showArchiveErrorAlert(archiveName: archiveURL.lastPathComponent, archiveURL: archiveURL, error: error, panel: panel)
        }
    }

    /// Navigate out of an archive: optionally repack if dirty (asks user), go to archive's parent dir
    func exitArchive(on panel: PanelSide) async {
        let state = archiveState(for: panel)
        guard state.isInsideArchive, let archiveURL = state.archiveURL else {
            log.warning("[AppState] exitArchive called but not inside archive on panel=\(panel)")
            return
        }

        let parentDir = archiveURL.deletingLastPathComponent().path
        log.info("[AppState] Exiting archive: \(archiveURL.lastPathComponent) → \(parentDir)")

        let session = await ArchiveManager.shared.sessionForArchive(at: archiveURL)
        let sessionDirty = session?.isDirty ?? false
        let fsDirty = await ArchiveManager.shared.isDirty(archiveURL: archiveURL)
        let isDirty = sessionDirty || fsDirty

        var shouldRepack = false
        if isDirty {
            shouldRepack = await confirmRepack(archiveName: archiveURL.lastPathComponent)
        }

        do {
            try await ArchiveManager.shared.closeArchive(at: archiveURL, repackIfDirty: shouldRepack)
        } catch {
            log.error("[AppState] Error closing archive: \(error.localizedDescription)")
        }

        var newState = archiveState(for: panel)
        newState.exitArchive()
        setArchiveState(newState, for: panel)

        updatePath(parentDir, for: panel)
        if panel == .left {
            await scanner.setLeftDirectory(pathStr: parentDir)
            await refreshLeftFiles()
        } else {
            await scanner.setRightDirectory(pathStr: parentDir)
            await refreshRightFiles()
        }
    }

    /// Shows NSAlert when archive open fails (encrypted, corrupted, etc.)
    @MainActor
    func showArchiveErrorAlert(archiveName: String, archiveURL: URL, error: Error, panel: PanelSide) async {
        let desc = error.localizedDescription
        let isEncrypted = desc.lowercased().contains("password") || desc.lowercased().contains("encrypted")

        let alert = NSAlert()
        alert.alertStyle = isEncrypted ? .warning : .critical

        if isEncrypted {
            alert.messageText = "Password Required"
            alert.informativeText = "\"\(archiveName)\" is password-protected.\nEnter password to open:"

            let passwordField = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
            passwordField.placeholderString = "Enter password"
            alert.accessoryView = passwordField

            alert.addButton(withTitle: "Open")
            alert.addButton(withTitle: "Open with App")
            alert.addButton(withTitle: "Cancel")

            alert.window.initialFirstResponder = passwordField
            let response = alert.runModal()

            if response == .alertFirstButtonReturn {
                let password = passwordField.stringValue
                log.debug("[Password dialog] entered password len=\(password.count)")
                if !password.isEmpty {
                    await enterArchive(at: archiveURL, on: panel, password: password)
                }
            } else if response == .alertSecondButtonReturn {
                NSWorkspace.shared.open(archiveURL)
            }
        } else {
            alert.messageText = "Cannot Open Archive"
            alert.informativeText = "\"\(archiveName)\" could not be opened.\n\n\(desc)"
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    /// Shows NSAlert asking user whether to repack the modified archive.
    @MainActor
    func confirmRepack(archiveName: String) async -> Bool {
        return await withCheckedContinuation { continuation in
            let alert = NSAlert()
            alert.messageText = "Archive Modified"
            alert.informativeText = "\"\(archiveName)\" has been modified.\n\nRepack the archive with your changes?"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Repack")
            alert.addButton(withTitle: "Discard Changes")
            let response = alert.runModal()
            continuation.resume(returning: response == .alertFirstButtonReturn)
        }
    }
}
