// BatchOperationManager.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 05.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Thin coordinator that delegates copy, move, and delete to FileOpsEngine.

import Foundation
import FileModelKit

// MARK: - Batch Operation Manager
/// Delegates file operations to FileOpsEngine; handles AppState refresh and mark clearing
@MainActor
@Observable
final class BatchOperationManager {

    static let shared = BatchOperationManager()

    private let engine = FileOpsEngine.shared

    private init() {
        log.debug("[BatchOperationManager] init")
    }

    // MARK: - Copy Files

    func copyFiles(
        _ files: [CustomFile],
        to destination: URL,
        from sourcePanel: FavPanelSide,
        appState: AppState
    ) async {
        MemoryDiagnostics.shared.checkpoint("copy.before")
        defer { MemoryDiagnostics.shared.checkpoint("copy.after") }
        log.info("[BatchOpMgr] copy \(files.count) → \(destination.path)")
        let urls = files.map(\.urlValue)
        await appState.scanner.beginBatchMutation()
        do {
            let progress = try await engine.copy(items: urls, to: destination)
            if progress.errors.isEmpty && !progress.isCancelled {
                appState.clearMarksAfterOperation(on: sourcePanel)
            }
        } catch {
            log.error("[BatchOpMgr] copy failed: \(error.localizedDescription)")
        }
        await appState.scanner.endBatchMutation()
        await refreshPanels(appState: appState)
    }

    // MARK: - Move Files

    func moveFiles(
        _ files: [CustomFile],
        to destination: URL,
        from sourcePanel: FavPanelSide,
        appState: AppState
    ) async {
        MemoryDiagnostics.shared.checkpoint("move.before")
        defer { MemoryDiagnostics.shared.checkpoint("move.after") }
        log.info("[BatchOpMgr] move \(files.count) → \(destination.path)")
        let urls = files.map(\.urlValue)
        await appState.scanner.beginBatchMutation()
        do {
            let progress = try await engine.move(items: urls, to: destination)
            if progress.errors.isEmpty && !progress.isCancelled {
                for file in files {
                    await ArchiveManager.shared.markDirtyByTempPath(file.pathStr)
                }
                appState.clearMarksAfterOperation(on: sourcePanel)
            }
        } catch {
            log.error("[BatchOpMgr] move failed: \(error.localizedDescription)")
        }
        await appState.scanner.endBatchMutation()
        await appState.refreshAndSelectAfterRemoval(removedFiles: files, on: sourcePanel)
        await refreshOpposite(appState: appState, sourcePanel: sourcePanel)
    }

    // MARK: - Delete Files

    func deleteFiles(
        _ files: [CustomFile],
        from sourcePanel: FavPanelSide,
        appState: AppState
    ) async {
        MemoryDiagnostics.shared.checkpoint("delete.before")
        defer { MemoryDiagnostics.shared.checkpoint("delete.after") }
        log.info("[BatchOpMgr] delete \(files.count)")
        let urls = files.map(\.urlValue)
        await appState.scanner.beginBatchMutation()
        do {
            let progress = try await engine.delete(items: urls)
            if progress.errors.isEmpty && !progress.isCancelled {
                appState.clearMarksAfterOperation(on: sourcePanel)
            }
        } catch {
            log.error("[BatchOpMgr] delete failed: \(error.localizedDescription)")
        }
        await appState.scanner.endBatchMutation()
        await appState.refreshAndSelectAfterRemoval(removedFiles: files, on: sourcePanel)
        await refreshOpposite(appState: appState, sourcePanel: sourcePanel)
    }

    // MARK: - Refresh Helpers

    private func refreshPanels(appState: AppState) async {
        await appState.refreshFiles(for: .left, force: true)
        await appState.refreshFiles(for: .right, force: true)
    }

    private func refreshOpposite(appState: AppState, sourcePanel: FavPanelSide) async {
        if sourcePanel == .left {
            await appState.refreshFiles(for: .right, force: true)
        } else {
            await appState.refreshFiles(for: .left, force: true)
        }
    }
}
