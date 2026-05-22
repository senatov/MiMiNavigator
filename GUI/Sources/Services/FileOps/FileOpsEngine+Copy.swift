// FileOpsEngine+Copy.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 22.05.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Copy implementation — opaque directory copy at top level.

import Foundation

// MARK: - Copy Implementation

extension FileOpsEngine {

    // MARK: - Perform Copy

    func performCopy(items: [URL], to destination: URL) async throws -> FileOpProgress {
        let directoryItems = items.filter { isDirectory(url: $0) }
        let fileItems = items.filter { !isDirectory(url: $0) }
        if directoryItems.isEmpty {
            let plan = await buildPlan(items: items, destination: destination)
            return try await executeWithPanel(plan: plan, operation: .copy)
        }
        let progress = createProgress(items: items, type: .copy, destination: destination)
        showPanel(progress: progress, itemCount: items.count, operation: "copy")
        defer { progress.complete() }
        var memorized: ConflictResolution? = nil
        for (index, item) in directoryItems.enumerated() {
            guard !progress.isCancelled else { break }
            let remaining = directoryItems.count - index
            let (target, skip, stop) = try await resolveConflictIfNeeded(
                source: item, destination: destination, remaining: remaining, memorized: &memorized)
            if stop { break }
            if skip {
                progress.fileSkipped(name: item.lastPathComponent)
                continue
            }
            progress.setCurrentFile(item.lastPathComponent)
            _ = await executeOpaqueDirectory(
                source: item, target: target, size: fileSize(url: item), operation: .copy, progress: progress)
        }
        if !fileItems.isEmpty, !progress.isCancelled {
            let plan = await buildPlan(items: fileItems, destination: destination)
            try await executeStrategy(plan: plan, operation: .copy, progress: progress)
        }
        return progress
    }
}
