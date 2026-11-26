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

    private func hideTransientPopups(_ reason: String) {
        InfoPopupController.hideAll(reason: "batch-\(reason)", immediate: true)
    }

    // MARK: - Copy Operation (F5)

    /// Initiate batch copy from focused panel to opposite panel.
    /// Remote source: downloads files via SFTP/FTP provider directly to destination.
    /// Local source: shows confirmation dialog then copies via FileOpsEngine.
    func initiateCopy(appState: AppState) {
        hideTransientPopups("copy")
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

        log.info("[BatchOperationCoordinator] initiateCopy: \(files.count) files to \(destination.path)")
        guard FileOperationConfirmation.isRequired(for: files.count) else {
            executeCopy(files: files, destination: destination, sourcePanel: sourcePanel, appState: appState, historyOnly: true)
            return
        }
        CntMenuCoord.shared.activeDialog = .batchCopyConfirmation(
            files: files, destination: destination, sourcePanel: sourcePanel
        )
    }

    // MARK: - Execute Copy
    func executeCopy(files: [CustomFile], destination: URL, sourcePanel: FavPanelSide, appState: AppState, inBackground: Bool = false, historyOnly: Bool = false) {
        executeTransfer(files: files, destination: destination, sourcePanel: sourcePanel, appState: appState, moveSource: false, inBackground: inBackground, historyOnly: historyOnly)
    }

    // MARK: - Move Operation (F6)

    /// Initiate batch move from focused panel to opposite panel
    func initiateMove(appState: AppState) {
        hideTransientPopups("move")
        let sourcePanel = appState.focusedPanel
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
        guard FileOperationConfirmation.isRequired(for: files.count) else {
            executeMove(files: files, destination: destination, sourcePanel: sourcePanel, appState: appState, historyOnly: true)
            return
        }
        CntMenuCoord.shared.activeDialog = .batchMoveConfirmation(
            files: files, destination: destination, sourcePanel: sourcePanel
        )
    }

    // MARK: - Execute Move
    func executeMove(files: [CustomFile], destination: URL, sourcePanel: FavPanelSide, appState: AppState, inBackground: Bool = false, historyOnly: Bool = false) {
        executeTransfer(files: files, destination: destination, sourcePanel: sourcePanel, appState: appState, moveSource: true, inBackground: inBackground, historyOnly: historyOnly)
    }

    // MARK: - Execute Transfer
    private func executeTransfer(
        files: [CustomFile], destination: URL, sourcePanel: FavPanelSide,
        appState: AppState, moveSource: Bool, inBackground: Bool, historyOnly: Bool
    ) {
        hideTransientPopups(moveSource ? "move-execute" : "copy-execute")
        let sourceIsRemote = files.contains { AppState.isRemotePath($0.urlValue) }
        let destinationIsRemote = AppState.isRemotePath(destination)
        Task {
            await ProgressPanel.runFileOperation(inBackground: inBackground, historyOnly: historyOnly, operation: moveSource ? .move : .copy) {
                if sourceIsRemote && destinationIsRemote {
                    await performRemoteToRemoteTransfer(files: files, destination: destination, sourcePanel: sourcePanel, appState: appState, moveSource: moveSource)
                } else if sourceIsRemote {
                    await performRemoteDownload(files: files, sourcePanel: sourcePanel, destination: destination, appState: appState, moveSource: moveSource)
                } else if destinationIsRemote {
                    let destinationPanel: FavPanelSide = sourcePanel == .left ? .right : .left
                    await performRemoteUpload(files: files, sourcePanel: sourcePanel, destinationPanel: destinationPanel, destinationURL: destination, appState: appState, moveSource: moveSource)
                } else if moveSource {
                    await batchManager.moveFiles(files, to: destination, from: sourcePanel, appState: appState)
                } else {
                    await batchManager.copyFiles(files, to: destination, from: sourcePanel, appState: appState)
                }
            }
        }
    }

    // MARK: - Delete Operation (F8)

    /// Initiate batch delete on focused panel
    func initiateDelete(appState: AppState) {
        hideTransientPopups("delete")
        let sourcePanel = appState.focusedPanel
        let files = appState.filesForOperation(on: sourcePanel).filter { !ParentDirectoryEntry.isParentEntry($0) }

        guard !files.isEmpty else {
            log.warning("[BatchOperationCoordinator] delete: no files selected")
            return
        }

        log.info("[BatchOperationCoordinator] initiateDelete: \(files.count) files")

        guard FileOperationConfirmation.isRequired(for: files.count) else {
            executeDelete(files: files, sourcePanel: sourcePanel, appState: appState, historyOnly: true)
            return
        }
        CntMenuCoord.shared.activeDialog = .batchDeleteConfirmation(
            files: files,
            sourcePanel: sourcePanel
        )
    }

    // MARK: - Execute Delete
    func executeDelete(files: [CustomFile], sourcePanel: FavPanelSide, appState: AppState, inBackground: Bool = false, historyOnly: Bool = false) {
        hideTransientPopups("delete-execute")
        let source = appState.url(for: sourcePanel)
        Task {
            await ProgressPanel.runFileOperation(inBackground: inBackground, historyOnly: historyOnly, operation: .delete) {
                if AppState.isRemotePath(source) {
                    await performRemoteDelete(files: files, source: source, sourcePanel: sourcePanel, appState: appState)
                } else {
                    await batchManager.deleteFiles(files, from: sourcePanel, appState: appState)
                }
            }
        }
    }

    // MARK: - Pack Operation

    /// Initiate batch pack (archive) operation
    func initiatePack(appState: AppState, archiveName: String, format: ArchiveFormat) {
        hideTransientPopups("pack")
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
            await CntMenuCoord.shared.performPack(
                files: files,
                archiveName: archiveName,
                format: format,
                destination: destination,
                appState: appState
            )
        }
    }

    // MARK: - Dismiss Dialog

    func dismissDialog() {
        CntMenuCoord.shared.dismissDialog()
    }
}
