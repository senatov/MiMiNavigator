// BatchOperationCoordinator.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 05.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Coordinates batch operations between UI and BatchOperationManager

import AppKit
import FileModelKit
import Foundation

// MARK: - Batch Operation Coordinator
/// Handles batch operation requests from toolbar/shortcuts, shows confirmations and progress
@MainActor
final class BatchOpsCoord {

    static let shared = BatchOpsCoord()

    private let batchManager = BatchOperationManager.shared

    private init() {
        log.debug("[BatchOperationCoordinator] initialized")
    }

    // MARK: - Copy Operation (F5)

    /// Initiate batch copy from focused panel to opposite panel.
    /// Remote source: downloads files via SFTP/FTP provider directly to destination.
    /// Local source: shows confirmation dialog then copies via FileOpsEngine.
    func initiateCopy(appState: AppState) {
        let sourcePanel = appState.focusedPanel
        let files = appState.filesForOperation(on: sourcePanel)
        let selectedFile = sourcePanel == .left ? appState.selectedLeftFile : appState.selectedRightFile
        log.info("[BatchOps] initiateCopy: panel=\(sourcePanel) selectedFile=\(selectedFile?.nameStr ?? "nil")")
        guard !files.isEmpty else {
            log.warning("[BatchOps] copy: no files selected")
            return
        }
        let destPanel: FavPanelSide = sourcePanel == .left ? .right : .left
        guard let destination = appState.pathURL(for: destPanel) else {
            log.error("[BatchOperationCoordinator] copy: invalid destination")
            return
        }

        // Remote source → download
        if AppState.isRemotePath(appState.url(for: sourcePanel)) {
            log.info("[BatchOps] remote copy: \(files.count) file(s) → \(destination.lastPathComponent)")
            Task { @MainActor in
                await performRemoteDownload(
                    files: files,
                    sourcePanel: sourcePanel,
                    destination: destination,
                    appState: appState
                )
            }
            return
        }

        // Local source → remote destination: upload
        if AppState.isRemotePath(appState.url(for: destPanel)) {
            log.info("[BatchOps] local→remote copy: \(files.count) file(s) → remote panel \(destPanel)")
            Task { @MainActor in
                await performRemoteUpload(
                    files: files,
                    sourcePanel: sourcePanel,
                    destinationPanel: destPanel,
                    appState: appState
                )
            }
            return
        }
        // Local → local: confirm then copy
        log.info("[BatchOperationCoordinator] initiateCopy: \(files.count) files to \(destination.path)")
        CntMenuCoord.shared.activeDialog = .batchCopyConfirmation(
            files: files, destination: destination, sourcePanel: sourcePanel
        )
    }

    /// Execute confirmed copy operation
    func executeCopy(files: [CustomFile], destination: URL, sourcePanel: FavPanelSide, appState: AppState) {
        log.info("[BatchOperationCoordinator] executeCopy: \(files.count) files")

        Task { @MainActor in
            await batchManager.copyFiles(files, to: destination, from: sourcePanel, appState: appState)
        }
    }

    // MARK: - Move Operation (F6)

    /// Initiate batch move from focused panel to opposite panel
    func initiateMove(appState: AppState) {
        let sourcePanel = appState.focusedPanel
        // Remote → local not supported
        if AppState.isRemotePath(appState.url(for: sourcePanel)) {
            ErrorAlertService.show(
                title: "Move from Remote Not Supported",
                message:
                    "Moving files from a remote SFTP/FTP panel is not yet supported.\nDownload the files first, then move them locally.",
                style: .informational
            )
            return
        }
        let files = appState.filesForOperation(on: sourcePanel)
        guard !files.isEmpty else {
            log.warning("[BatchOperationCoordinator] move: no files selected")
            return
        }
        let destinationURL = appState.pathURL(for: sourcePanel == .left ? .right : .left)
        guard let destination = destinationURL else {
            log.error("[BatchOperationCoordinator] move: invalid destination")
            return
        }
        log.info("[BatchOperationCoordinator] initiateMove: \(files.count) files to \(destination.path)")
        CntMenuCoord.shared.activeDialog = .batchMoveConfirmation(
            files: files, destination: destination, sourcePanel: sourcePanel
        )
    }

    /// Execute confirmed move operation
    func executeMove(files: [CustomFile], destination: URL, sourcePanel: FavPanelSide, appState: AppState) {
        log.info("[BatchOperationCoordinator] executeMove: \(files.count) files")

        Task { @MainActor in
            await batchManager.moveFiles(files, to: destination, from: sourcePanel, appState: appState)
        }
    }

    // MARK: - Delete Operation (F8)

    /// Initiate batch delete on focused panel
    func initiateDelete(appState: AppState) {
        let sourcePanel = appState.focusedPanel
        let files = appState.filesForOperation(on: sourcePanel)

        guard !files.isEmpty else {
            log.warning("[BatchOperationCoordinator] delete: no files selected")
            return
        }

        log.info("[BatchOperationCoordinator] initiateDelete: \(files.count) files")

        CntMenuCoord.shared.activeDialog = .batchDeleteConfirmation(
            files: files,
            sourcePanel: sourcePanel
        )
    }

    /// Execute confirmed delete operation
    func executeDelete(files: [CustomFile], sourcePanel: FavPanelSide, appState: AppState) {
        log.info("[BatchOperationCoordinator] executeDelete: \(files.count) files")

        Task { @MainActor in
            await batchManager.deleteFiles(files, from: sourcePanel, appState: appState)
        }
    }

    // MARK: - Pack Operation

    /// Initiate batch pack (archive) operation
    func initiatePack(appState: AppState, archiveName: String, format: ArchiveFormat) {
        let sourcePanel = appState.focusedPanel
        let files = appState.filesForOperation(on: sourcePanel)

        guard !files.isEmpty else {
            log.warning("[BatchOperationCoordinator] pack: no files selected")
            return
        }

        let destinationURL = appState.pathURL(for: sourcePanel == .left ? .right : .left)
        guard let destination = destinationURL else {
            log.error("[BatchOperationCoordinator] pack: invalid destination")
            return
        }

        let archiveURL = destination.appendingPathComponent("\(archiveName).\(format.fileExtension)")

        log.info("[BatchOperationCoordinator] initiatePack: \(files.count) files to \(archiveURL.path)")

        Task { @MainActor in
            await batchManager.packFiles(files, to: archiveURL, format: format, from: sourcePanel, appState: appState)
        }
    }

    // MARK: - Cancel Current Operation

    func cancelCurrentOperation() {
        batchManager.cancelCurrentOperation()
    }

    // MARK: - Dismiss Dialog

    func dismissDialog() {
        CntMenuCoord.shared.dismissDialog()
        batchManager.dismissProgressDialog()
    }

    // MARK: - Check if operation is in progress

    var isOperationInProgress: Bool {
        batchManager.currentOperation != nil && !(batchManager.currentOperation?.isCompleted ?? true)
    }

    var currentOperationState: BatchOperationState? {
        batchManager.currentOperation
    }
}
