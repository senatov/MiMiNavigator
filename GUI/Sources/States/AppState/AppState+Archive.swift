// AppState+Archive.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 11.03.2026.
// Copyright © 2025-2026 Senatov. All rights reserved.
// Description: Archive enter/exit, password dialogs, repack confirmation.

import AppKit
import FileModelKit
import Foundation

// MARK: - Archive Navigation
extension AppState {

    /// Navigate into an archive: extract to temp dir and open as directory
    func enterArchive(at archiveURL: URL, on panel: FavPanelSide, password: String? = nil) async {
        log.info("[AppState] Entering archive: \(archiveURL.lastPathComponent) panel=\(panel) hasPassword=\(password != nil)")

        let progressPanel = ProgressPanel.shared
        let handle = ActiveArchiveProcess()

        await MainActor.run {
            progressPanel.show(
                archiveName: archiveURL.lastPathComponent,
                destinationPath: archiveURL.deletingLastPathComponent().path,
                cancelHandler: { [handle] in
                    log.info("[AppState] User cancelled archive extraction")
                    handle.terminate()
                }
            )
            progressPanel.appendLog("⏳ Decompressing \(archiveURL.lastPathComponent)…")
        }

        let onProgress: @Sendable (String) -> Void = { line in
            Task { @MainActor in
                progressPanel.appendLog(line)
            }
        }

        do {
            let tempDir = try await ArchiveManager.shared.openArchive(
                at: archiveURL, password: password,
                onProgress: onProgress, processHandle: handle
            )
            await MainActor.run {
                progressPanel.finish(success: true)
            }
            applyArchiveOpenState(tempDir: tempDir, archiveURL: archiveURL, for: panel)
            await activateArchiveDirectory(tempDir, for: panel)
            log.info("[AppState] Successfully entered archive: \(archiveURL.lastPathComponent)")
        } catch {
            await MainActor.run {
                if progressPanel.isCancelled {
                    progressPanel.finish(success: false, message: "⏹ Cancelled by user")
                } else {
                    progressPanel.finish(success: false, message: "❌ \(error.localizedDescription)")
                }
            }
            log.error("[AppState] Failed to enter archive: \(error.localizedDescription)")
        }
    }

    /// Navigate out of an archive: optionally repack if dirty, go to archive's parent dir
    func exitArchive(on panel: FavPanelSide) async {
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
        clearArchiveOpenState(for: panel)
        await activateLocalDirectory(parentDirURL, for: panel)
    }

    // MARK: - Archive Open State
    @MainActor
    private func applyArchiveOpenState(tempDir: URL, archiveURL: URL, for panel: FavPanelSide) {
        var state = archiveState(for: panel)
        state.enterArchive(archiveURL: archiveURL, tempDir: tempDir)
        setArchiveState(state, for: panel)
        tabManager(for: panel).updateActiveTabForArchive(extractedURL: tempDir, archiveURL: archiveURL)
        updatePath(tempDir, for: panel)
    }

    @MainActor
    private func clearArchiveOpenState(for panel: FavPanelSide) {
        var newState = archiveState(for: panel)
        newState.exitArchive()
        setArchiveState(newState, for: panel)
    }

    private func activateArchiveDirectory(_ tempDir: URL, for panel: FavPanelSide) async {
        log.info("[AppState] activateArchiveDirectory panel=\(panel) path=\(tempDir.path)")
        await activateLocalDirectory(tempDir, for: panel)
    }

    private func activateLocalDirectory(_ directoryURL: URL, for panel: FavPanelSide) async {
        await MainActor.run {
            updatePath(directoryURL, for: panel)
        }

        switch panel {
            case .left:
                await scanner.setLeftDirectory(pathStr: directoryURL.path)
            case .right:
                await scanner.setRightDirectory(pathStr: directoryURL.path)
        }

        await scanner.forceRefreshAfterFileOp(side: panel)
        await refreshFiles(for: panel)
    }

    // MARK: - Archive Error Alert
    @MainActor
    func showArchiveErrorAlert(archiveName: String, archiveURL: URL, error: Error, panel: FavPanelSide) async {
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
