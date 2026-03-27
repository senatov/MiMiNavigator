// BatchOperationCoordinator.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 05.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Coordinates batch operations between UI and BatchOperationManager

import AppKit
import Foundation
import FileModelKit

// MARK: - Batch Operation Coordinator
/// Handles batch operation requests from toolbar/shortcuts, shows confirmations and progress
@MainActor
final class BatchOperationCoordinator {
    
    static let shared = BatchOperationCoordinator()
    
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
                await performRemoteDownload(files: files, to: destination,
                                            sourcePanel: sourcePanel, appState: appState)
            }
            return
        }

        // Remote destination → can't copy local→remote yet
        if AppState.isRemotePath(appState.url(for: destPanel)) {
            ErrorAlertService.show(
                title: "Copy to Remote Not Supported",
                message: "Uploading files to a remote SFTP/FTP panel is not yet supported.",
                style: .informational
            )
            return
        }
        // Local → local: confirm then copy
        log.info("[BatchOperationCoordinator] initiateCopy: \(files.count) files to \(destination.path)")
        ContextMenuCoordinator.shared.activeDialog = .batchCopyConfirmation(
            files: files, destination: destination, sourcePanel: sourcePanel
        )
    }

    // MARK: - Remote Download (F5 from SFTP/FTP panel)
    /// Downloads selected remote files/directories to the opposite local panel.
    /// Shows ProgressPanel with Cancel for long ops. Supports directories via `scp -r`.
    private var cancelledDownload = false

    private func performRemoteDownload(
        files: [CustomFile],
        to destination: URL,
        sourcePanel: FavPanelSide,
        appState: AppState
    ) async {
        let manager = RemoteConnectionManager.shared
        guard let conn = manager.activeConnection else {
            log.error("[BatchOps] remote download — no active connection")
            ErrorAlertService.show(title: "Not Connected",
                                   message: "No active SFTP/FTP connection.", style: .warning)
            return
        }
        cancelledDownload = false
        let panel = ProgressPanel.shared
        let totalItems = files.count
        let totalSize = files.reduce(Int64(0)) { $0 + $1.sizeInBytes }
        let sizeStr = ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
        panel.showFileOp(
            icon: "arrow.down.doc.fill",
            title: "⬇ Downloading \(totalItems) item(s) — \(sizeStr)",
            itemCount: totalItems,
            destination: destination.path,
            cancelHandler: { [weak self] in self?.cancelledDownload = true }
        )
        var ok = 0; var fail = 0
        for (idx, file) in files.enumerated() {
            guard !cancelledDownload else {
                panel.appendLog("⛔ Cancelled by user")
                break
            }
            let remotePath = file.urlValue.path
            let finalURL = destination.appendingPathComponent(file.nameStr)
            let isDir = file.isDirectory
            panel.updateStatus("[\(idx + 1)/\(totalItems)] \(file.nameStr)")
            do {
                if isDir {
                    // Directory: scp -r directly to destination
                    if FileManager.default.fileExists(atPath: finalURL.path) {
                        try FileManager.default.removeItem(at: finalURL)
                    }
                    try await conn.provider.downloadToLocal(
                        remotePath: remotePath, localPath: finalURL.path, recursive: true
                    )
                    panel.appendLog("📁 \(file.nameStr)/")
                } else {
                    // File: download to tmp, then move
                    let tmpURL = try await conn.provider.downloadFile(remotePath: remotePath)
                    if FileManager.default.fileExists(atPath: finalURL.path) {
                        try FileManager.default.removeItem(at: finalURL)
                    }
                    try FileManager.default.moveItem(at: tmpURL, to: finalURL)
                    let sz = (try? FileManager.default.attributesOfItem(atPath: finalURL.path)[.size] as? Int64) ?? 0
                    let szStr = ByteCountFormatter.string(fromByteCount: sz, countStyle: .file)
                    panel.appendLog("📄 \(file.nameStr) (\(szStr))")
                }
                log.info("[BatchOps] downloaded '\(file.nameStr)' → '\(destination.lastPathComponent)'")
                ok += 1
            } catch {
                log.error("[BatchOps] download '\(file.nameStr)' failed: \(error.localizedDescription)")
                panel.appendLog("❌ \(file.nameStr): \(error.localizedDescription)")
                fail += 1
            }
        }
        log.info("[BatchOps] remote download done: ok=\(ok) fail=\(fail)")
        if cancelledDownload {
            panel.finish(success: false, message: "⏹ Cancelled — \(ok) downloaded, \(fail) failed")
        } else if fail > 0 {
            panel.finish(success: false, message: "⚠️ \(ok) downloaded, \(fail) failed")
        } else {
            panel.finish(success: true, message: "✅ \(ok) item(s) downloaded")
        }
        // Refresh destination (local) panel
        await appState.refreshFiles(for: sourcePanel == .left ? .right : .left, force: true)
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
                message: "Moving files from a remote SFTP/FTP panel is not yet supported.\nDownload the files first, then move them locally.",
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
        ContextMenuCoordinator.shared.activeDialog = .batchMoveConfirmation(
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
        
        ContextMenuCoordinator.shared.activeDialog = .batchDeleteConfirmation(
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
        ContextMenuCoordinator.shared.dismissDialog()
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
