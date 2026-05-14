// FileOpsEngine+ManySmall.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 14.05.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: ManySmall strategy — parallel TaskGroup for batches > 50 files.

import Foundation

// MARK: - Resolved entry for pre-scanned conflict resolution

struct ResolvedEntry: Sendable {
    let source: URL
    let target: URL
    let size: Int64
    var isLarge: Bool { size > FileOpStrategy.largeFileThreshold }
}

// MARK: - Strategy: ManySmall

extension FileOpsEngine {

    func executeManySmall(plan: FileOpPlan, operation: FileOpType, progress: FileOpProgress) async throws {
        createDirectoryStructure(plan: plan)
        var memorized: ConflictResolution? = nil
        let fileEntries = plan.flatList.filter { !$0.isDirectory }
        var smallBatch: [ResolvedEntry] = []
        var largeBatch: [ResolvedEntry] = []
        for (index, entry) in fileEntries.enumerated() {
            guard !progress.isCancelled else { break }
            let remaining = fileEntries.count - index
            let targetDir = plan.destination.appendingPathComponent(
                (entry.relativePath as NSString).deletingLastPathComponent)
            let targetURL = targetDir.appendingPathComponent(entry.url.lastPathComponent)
            let resolved: ResolvedEntry
            if fm.fileExists(atPath: targetURL.path) {
                let (finalTarget, skip, stop) = try await resolveConflictIfNeeded(
                    source: entry.url, destination: targetDir, remaining: remaining, memorized: &memorized)
                if stop { break }
                if skip { progress.fileSkipped(name: entry.url.lastPathComponent); continue }
                resolved = ResolvedEntry(source: entry.url, target: finalTarget, size: entry.size)
            } else {
                resolved = ResolvedEntry(source: entry.url, target: targetURL, size: entry.size)
            }
            if resolved.isLarge {
                largeBatch.append(resolved)
            } else {
                smallBatch.append(resolved)
            }
        }
        try await dispatchSmallBatch(smallBatch, operation: operation, progress: progress)
        try await dispatchLargeBatch(largeBatch, operation: operation, progress: progress)
        if operation == .move { cleanupEmptyDirs(plan: plan) }
    }



    /// parallel dispatch for small files via TaskGroup
    private func dispatchSmallBatch(
        _ batch: [ResolvedEntry],
        operation: FileOpType,
        progress: FileOpProgress
    ) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            var running = 0
            for entry in batch {
                guard !progress.isCancelled else { break }
                if running >= maxConcurrency {
                    try await group.next()
                    running -= 1
                }
                progress.setCurrentFile(entry.source.lastPathComponent)
                group.addTask(priority: .userInitiated) {
                    let result = Self.performIO(from: entry.source, to: entry.target, operation: operation)
                    await MainActor.run {
                        if result.succeeded {
                            progress.fileCompleted(name: entry.source.lastPathComponent, success: true)
                            progress.add(bytes: result.bytes)
                        } else if let diagnostic = result.diagnostic {
                            self.recordFailure(diagnostic, progress: progress)
                        }
                    }
                }
                running += 1
            }
            try await group.waitForAll()
        }
    }



    /// sequential streamCopy for large files (live byte progress)
    private func dispatchLargeBatch(
        _ batch: [ResolvedEntry],
        operation: FileOpType,
        progress: FileOpProgress
    ) async throws {
        for entry in batch {
            guard !progress.isCancelled else { break }
            progress.setCurrentFile(entry.source.lastPathComponent)
            do {
                let didAtomicMove = operation == .move
                    ? await tryAtomicMove(from: entry.source, to: entry.target)
                    : false
                if didAtomicMove {
                    progress.fileCompleted(name: entry.source.lastPathComponent, success: true)
                    progress.add(bytes: entry.size)
                    continue
                }
                if isDirectory(url: entry.source) {
                    _ = await executeOpaqueDirectory(
                        source: entry.source, target: entry.target,
                        size: entry.size, operation: operation, progress: progress)
                    continue
                }
                try await streamCopy(from: entry.source, to: entry.target, progress: progress)
                if operation == .move { try fm.removeItem(at: entry.source) }
                progress.fileCompleted(name: entry.source.lastPathComponent, success: true)
            } catch {
                recordFailure(
                    FileOperationDiagnostics.make(operation: operation, source: entry.source, target: entry.target, error: error),
                    progress: progress)
            }
        }
    }



    func createDirectoryStructure(plan: FileOpPlan) {
        for entry in plan.flatList where entry.isDirectory {
            let targetDir = plan.destination.appendingPathComponent(entry.relativePath)
            try? fm.createDirectory(at: targetDir, withIntermediateDirectories: true)
        }
    }
}
