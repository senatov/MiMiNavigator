// DuoFilePanelActions.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 27.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: File operation actions for the dual-panel view

import AppKit
import Foundation

/// File operation actions performed from DuoFilePanelView
/// Extracted to separate concerns from the main view
@MainActor
struct DuoFilePanelActions {
    let appState: AppState
    let refreshBothPanels: @concurrent @Sendable () async -> Void

    // MARK: - F3 View
    func performView() {
        log.debug("performView - View button pressed")

        guard FileActions.isVSCodeInstalled() else {
            FileActions.promptVSCodeInstall {}
            return
        }

        guard let file = currentSelectedFile else {
            log.debug("No file selected for View")
            return
        }

        guard !file.isDirectory else {
            log.debug("Cannot view directory")
            return
        }

        FileActions.view(file)
    }

    // MARK: - F4 Edit
    func performEdit() {
        log.debug("performEdit - Edit button pressed")

        guard FileActions.isVSCodeInstalled() else {
            FileActions.promptVSCodeInstall {}
            return
        }

        guard let file = currentSelectedFile else {
            log.debug("No file selected for Edit")
            return
        }

        guard !file.isDirectory else {
            log.debug("Cannot edit directory")
            return
        }

        FileActions.edit(file)
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

        FileActions.createFolderWithDialog(at: currentURL) {
            Task {
                await refreshBothPanels()
            }
        }
    }

    // MARK: - Delete (Fwd-Delete / F8) — move to Trash without confirmation
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

        log.info("performDelete: recycling \(urls.count) item(s): \(urls.map(\.lastPathComponent))")

        NSWorkspace.shared.recycle(urls) { trashedURLs, error in
            if let error {
                log.error("performDelete: recycle failed — \(error.localizedDescription)")
                return
            }
            log.info("performDelete: \(trashedURLs.count) item(s) moved to Trash ✓")

            Task { @MainActor in
                if panel == .left {
                    await self.appState.refreshLeftFiles()
                } else {
                    await self.appState.refreshRightFiles()
                }
                self.appState.unmarkAll()
            }
        }
    }

    // MARK: - Settings
    func performSettings() {
        log.debug("performSettings - Settings button pressed")
        // TODO: Implement settings panel
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
        appState.saveBeforeExit()
        NSApplication.shared.terminate(nil)
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
