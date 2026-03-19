// AppState+Archive.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 11.03.2026.
// Copyright © 2025-2026 Senatov. All rights reserved.
// Description: Archive enter/exit, password dialogs, repack confirmation.
//              Uses setScannerDirectoryAndRefresh to avoid left/right branching.

import AppKit
import FileModelKit
import Foundation

// MARK: - Archive Navigation
extension AppState {

    /// Navigate into an archive: extract to temp dir and open as directory
    func enterArchive(at archiveURL: URL, on panel: PanelSide, password: String? = nil) async {
        log.info("[AppState] Entering archive: \(archiveURL.lastPathComponent) panel=\(panel) hasPassword=\(password != nil)")

        let progressPanel = ArchiveProgressPanel.shared
        await MainActor.run {
            progressPanel.show(
                archiveName: archiveURL.lastPathComponent,
                destinationPath: archiveURL.deletingLastPathComponent().path,
                cancelHandler: {
                    log.info("[AppState] Archive extraction cancelled by user")
                }
            )
        }

        // Progress callback — runs on bg thread, dispatches UI update to main
        let onProgress: @Sendable (String) -> Void = { line in
            Task { @MainActor in
                progressPanel.appendLog(line)
            }
        }

        do {
            let tempDir = try await ArchiveManager.shared.openArchive(
                at: archiveURL, password: password, onProgress: onProgress
            )
            await MainActor.run {
                progressPanel.finish(success: true)
            }
            var state = archiveState(for: panel)
            state.enterArchive(archiveURL: archiveURL, tempDir: tempDir)
            setArchiveState(state, for: panel)
            tabManager(for: panel).updateActiveTabForArchive(extractedURL: tempDir, archiveURL: archiveURL)
            updatePath(tempDir, for: panel)
            await setScannerDirectoryAndRefresh(tempDir.path, for: panel)
            log.info("[AppState] Successfully entered archive: \(archiveURL.lastPathComponent)")
        } catch {
            await MainActor.run {
                progressPanel.finish(success: false, message: "❌ \(error.localizedDescription)")
            }
            log.error("[AppState] Failed to enter archive: \(error.localizedDescription)")
        }
    }

    /// Navigate out of an archive: optionally repack if dirty, go to archive's parent dir
    func exitArchive(on panel: PanelSide) async {
        let state = archiveState(for: panel)
        guard state.isInsideArchive, let archiveURL = state.archiveURL else {
            log.warning("[AppState] exitArchive called but not inside archive on panel=\(panel)")
            return
        }
        let parentDirURL = archiveURL.deletingLastPathComponent()
        log.info("[AppState] Exiting archive: \(archiveURL.lastPathComponent) → \(parentDirURL.path)")
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
        updatePath(parentDirURL, for: panel)
        await setScannerDirectoryAndRefresh(parentDirURL.path, for: panel)
    }

    // MARK: - Archive Error Alert
    @MainActor
    func showArchiveErrorAlert(archiveName: String, archiveURL: URL, error: Error, panel: PanelSide) async {
        let desc = error.localizedDescription
        let isEncrypted = desc.lowercased().contains("password") || desc.lowercased().contains("encrypted")
        if isEncrypted {
            let (password, openWithApp) = ErrorAlertService.promptPassword(archiveName: archiveName)
            if openWithApp {
                NSWorkspace.shared.open(archiveURL)
            } else if let pwd = password {
                await enterArchive(at: archiveURL, on: panel, password: pwd)
            }
        } else {
            ErrorAlertService.show(
                title: "Cannot Open Archive",
                message: "\"\(archiveName)\" could not be opened.\n\n\(desc)",
                style: .critical
            )
        }
    }

    // MARK: - Repack Confirmation
    @MainActor
    func confirmRepack(archiveName: String) async -> Bool {
        ErrorAlertService.confirm(
            title: "Archive Modified",
            message: "\"\(archiveName)\" has been modified.\n\nRepack the archive with your changes?",
            confirmButton: "Repack",
            cancelButton: "Discard Changes"
        )
    }
}
