// BatchOperationManager.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 05.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Thin coordinator — delegates copy/move/delete to FileOpsEngine, keeps pack logic

import Foundation
import FileModelKit

// MARK: - Batch Operation Manager
/// Delegates file operations to FileOpsEngine; handles AppState refresh and mark clearing
@MainActor
@Observable
final class BatchOperationManager {

    static let shared = BatchOperationManager()

    // MARK: - State (kept for BatchProgressDialog compatibility)
    var currentOperation: BatchOperationState?
    var showProgressDialog: Bool = false

    private let engine = FileOpsEngine.shared

    private init() {
        log.debug("[BatchOperationManager] init")
    }

    // MARK: - Copy Files

    func copyFiles(
        _ files: [CustomFile],
        to destination: URL,
        from sourcePanel: PanelSide,
        appState: AppState
    ) async {
        log.info("[BatchOpMgr] copy \(files.count) → \(destination.path)")
        let urls = files.map(\.urlValue)
        do {
            let progress = try await engine.copy(items: urls, to: destination)
            if progress.errors.isEmpty && !progress.isCancelled {
                appState.clearMarksAfterOperation(on: sourcePanel)
            }
        } catch {
            log.error("[BatchOpMgr] copy failed: \(error.localizedDescription)")
        }
        await refreshPanels(appState: appState)
    }

    // MARK: - Move Files

    func moveFiles(
        _ files: [CustomFile],
        to destination: URL,
        from sourcePanel: PanelSide,
        appState: AppState
    ) async {
        log.info("[BatchOpMgr] move \(files.count) → \(destination.path)")
        let urls = files.map(\.urlValue)
        do {
            let progress = try await engine.move(items: urls, to: destination)
            if progress.errors.isEmpty && !progress.isCancelled {
                appState.clearMarksAfterOperation(on: sourcePanel)
            }
        } catch {
            log.error("[BatchOpMgr] move failed: \(error.localizedDescription)")
        }
        await appState.refreshAndSelectAfterRemoval(removedFiles: files, on: sourcePanel)
        await refreshOpposite(appState: appState, sourcePanel: sourcePanel)
    }

    // MARK: - Delete Files

    func deleteFiles(
        _ files: [CustomFile],
        from sourcePanel: PanelSide,
        appState: AppState
    ) async {
        log.info("[BatchOpMgr] delete \(files.count)")
        let urls = files.map(\.urlValue)
        do {
            let progress = try await engine.delete(items: urls)
            if progress.errors.isEmpty && !progress.isCancelled {
                appState.clearMarksAfterOperation(on: sourcePanel)
            }
        } catch {
            log.error("[BatchOpMgr] delete failed: \(error.localizedDescription)")
        }
        await appState.refreshAndSelectAfterRemoval(removedFiles: files, on: sourcePanel)
        await refreshOpposite(appState: appState, sourcePanel: sourcePanel)
    }

    // MARK: - Pack Files (archive — stays here, not in FileOpsEngine)

    func packFiles(
        _ files: [CustomFile],
        to archiveURL: URL,
        format: ArchiveFormat,
        from sourcePanel: PanelSide,
        appState: AppState
    ) async {
        log.info("[BatchOpMgr] pack \(files.count) → \(archiveURL.path)")

        let state = BatchOperationState(
            operationType: .pack,
            sourcePanel: sourcePanel,
            destinationURL: archiveURL.deletingLastPathComponent(),
            files: files
        )
        currentOperation = state
        showProgressDialog = true
        state.updateProgress(fileName: archiveURL.lastPathComponent, fileSize: state.totalBytes)

        var hasErrors = false
        do {
            try await ArchiveService.shared.createArchive(
                from: files.map(\.urlValue),
                to: archiveURL,
                format: format,
                progressHandler: { progress in
                    state.processedBytes = Int64(Double(state.totalBytes) * progress)
                }
            )
            state.processedFiles = files.count
        } catch {
            hasErrors = true
            state.fileCompleted(success: false, error: error.localizedDescription)
        }

        state.complete()
        showProgressDialog = false
        currentOperation = nil

        if !hasErrors && !state.isCancelled {
            appState.clearMarksAfterOperation(on: sourcePanel)
        }
        await refreshPanels(appState: appState)
    }

    // MARK: - Cancel

    func cancelCurrentOperation() {
        currentOperation?.cancel()
        log.info("[BatchOpMgr] cancelled")
    }

    func dismissProgressDialog() {
        showProgressDialog = false
        currentOperation = nil
    }

    // MARK: - Refresh Helpers

    private func refreshPanels(appState: AppState) async {
        await appState.refreshLeftFiles()
        await appState.refreshRightFiles()
    }

    private func refreshOpposite(appState: AppState, sourcePanel: PanelSide) async {
        if sourcePanel == .left {
            await appState.refreshRightFiles()
        } else {
            await appState.refreshLeftFiles()
        }
    }
}

