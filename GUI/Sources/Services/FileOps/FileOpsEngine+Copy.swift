// FileOpsEngine+Copy.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 22.05.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Copy implementation — manifest-based copy with per-file progress.

import Foundation

// MARK: - Copy Implementation

extension FileOpsEngine {

    // MARK: - Perform Copy

    func performCopy(items: [URL], to destination: URL) async throws -> FileOpProgress {
        let progress = createProgress(items: items, type: .copy, destination: destination)
        showPanel(progress: progress, itemCount: items.count, operation: "copy")
        progress.updateStatusOnly("Scanning selected items…")
        panel.updateProgress(nil)
        let plan = await buildPlan(items: items, destination: destination)
        if progress.isCancelled { return progress }
        return try await executeWithPanel(plan: plan, operation: .copy, existingProgress: progress)
    }
}
