// BatchOperationCoordinator.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 05.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Coordinates batch operations between UI and BatchOperationManager

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
    
    /// Initiate batch copy from focused panel to opposite panel
    func initiateCopy(appState: AppState) {
        let sourcePanel = appState.focusedPanel
        let files = appState.filesForOperation(on: sourcePanel)
        
        guard !files.isEmpty else {
            log.warning("[BatchOperationCoordinator] copy: no files selected")
            return
        }
        
        let destinationURL = appState.pathURL(for: sourcePanel == .left ? .right : .left)
        guard let destination = destinationURL else {
            log.error("[BatchOperationCoordinator] copy: invalid destination")
            return
        }
        
        log.info("[BatchOperationCoordinator] initiateCopy: \(files.count) files to \(destination.path)")
        
        // Show confirmation dialog via ContextMenuCoordinator
        ContextMenuCoordinator.shared.activeDialog = .batchCopyConfirmation(
            files: files,
            destination: destination,
            sourcePanel: sourcePanel
        )
    }
    
    /// Execute confirmed copy operation
    func executeCopy(files: [CustomFile], destination: URL, sourcePanel: PanelSide, appState: AppState) {
        log.info("[BatchOperationCoordinator] executeCopy: \(files.count) files")
        
        Task { @MainActor in
            await batchManager.copyFiles(files, to: destination, from: sourcePanel, appState: appState)
        }
    }
    
    // MARK: - Move Operation (F6)
    
    /// Initiate batch move from focused panel to opposite panel
    func initiateMove(appState: AppState) {
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
        
        ContextMenuCoordinator.shared.activeDialog = .batchMoveConfirmation(
            files: files,
            destination: destination,
            sourcePanel: sourcePanel
        )
    }
    
    /// Execute confirmed move operation
    func executeMove(files: [CustomFile], destination: URL, sourcePanel: PanelSide, appState: AppState) {
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
    func executeDelete(files: [CustomFile], sourcePanel: PanelSide, appState: AppState) {
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
