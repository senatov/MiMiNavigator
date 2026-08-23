// MultiRenameOperationCoordinator.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Orchestrates multi-rename execution and the required panel refresh.

import Foundation

// MARK: - Multi Rename Operation Coordinator
@MainActor
final class MultiRenameOperationCoordinator {
    private let engine = MultiRenameEngine()

    // MARK: - Execute
    func execute(
        items: [MultiRenamePreviewItem],
        appState: AppState?,
        panel: FavPanelSide
    ) async throws -> MultiRenameResult {
        let result = try await engine.rename(items)
        guard let appState else { return result }
        await appState.scanner.clearCooldown(for: panel)
        await appState.refreshFiles(for: panel, force: true)
        appState.setMarkedFiles([], for: panel)
        return result
    }
}
