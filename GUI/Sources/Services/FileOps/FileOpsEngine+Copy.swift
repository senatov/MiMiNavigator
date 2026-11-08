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
        progress.setTotals(files: plan.fileCount, bytes: plan.totalBytes)
        let missingBytes = plan.flatList.reduce(Int64(0)) { total, entry in
            guard !entry.isDirectory,
                  !fm.fileExists(atPath: destination.appendingPathComponent(entry.relativePath).path) else { return total }
            return total + entry.size
        }
        if let freeBytes = await availableSpace(at: destination), missingBytes > freeBytes {
            let required = ByteCountFormatter.string(fromByteCount: missingBytes, countStyle: .file)
            let available = ByteCountFormatter.string(fromByteCount: freeBytes, countStyle: .file)
            progress.fileCompleted(
                name: "Destination",
                success: false,
                error: "Insufficient free space. Required: \(required); available: \(available). No files were copied."
            )
            progress.complete()
            return progress
        }
        return try await executeWithPanel(plan: plan, operation: .copy, existingProgress: progress)
    }
}
