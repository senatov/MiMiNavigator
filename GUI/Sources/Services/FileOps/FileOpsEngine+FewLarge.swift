// FileOpsEngine+FewLarge.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 14.05.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: FewLarge strategy — stream-copy with byte-level progress for big files.

import Foundation

// MARK: - Strategy: FewLarge

extension FileOpsEngine {

    func executeFewLarge(plan: FileOpPlan, operation: FileOpType, progress: FileOpProgress) async throws {
        createDirectoryStructure(plan: plan)
        var memorized: ConflictResolution? = nil
        let fileEntries = plan.flatList.filter { !$0.isDirectory }
        for (index, entry) in fileEntries.enumerated() {
            guard !progress.isCancelled else { break }
            let remaining = fileEntries.count - index
            let targetDir = plan.destination.appendingPathComponent(
                (entry.relativePath as NSString).deletingLastPathComponent)
            let targetURL = targetDir.appendingPathComponent(entry.url.lastPathComponent)
            let finalTarget: URL
            if fm.fileExists(atPath: targetURL.path) {
                let (resolved, skip, stop) = try await resolveConflictIfNeeded(
                    source: entry.url, destination: targetDir, operation: operation, remaining: remaining, memorized: &memorized)
                if stop { break }
                if skip { progress.fileSkipped(name: entry.url.lastPathComponent); continue }
                finalTarget = resolved
            } else {
                finalTarget = targetURL
            }
            progress.setCurrentFile(entry.url.lastPathComponent)
            do {
                let didAtomicMove = operation == .move
                    ? await tryAtomicMove(from: entry.url, to: finalTarget)
                    : false
                if didAtomicMove {
                    progress.fileCompleted(name: entry.url.lastPathComponent, success: true)
                    progress.add(bytes: entry.size)
                    continue
                }
                if isDirectory(url: entry.url) {
                    _ = await executeOpaqueDirectory(
                        source: entry.url, target: finalTarget,
                        size: entry.size, operation: operation, progress: progress)
                    continue
                }
                try await streamCopy(from: entry.url, to: finalTarget, progress: progress)
                if operation == .move { try fm.removeItem(at: entry.url) }
                progress.fileCompleted(name: entry.url.lastPathComponent, success: true)
            } catch {
                recordFailure(
                    FileOperationDiagnostics.make(operation: operation, source: entry.url, target: finalTarget, error: error),
                    progress: progress)
            }
        }
        if operation == .move { cleanupEmptyDirs(plan: plan) }
    }
}
