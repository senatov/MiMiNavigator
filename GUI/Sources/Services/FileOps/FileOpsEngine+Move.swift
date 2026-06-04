// FileOpsEngine+Move.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 14.05.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Move implementation — atomic same-volume + cross-volume fallback.

import Foundation

// MARK: - Move Implementation

extension FileOpsEngine {

    func performMove(items: [URL], to destination: URL) async throws -> FileOpProgress {
        let progress = createProgress(items: items, type: .move, destination: destination)
        var memorized: ConflictResolution? = nil
        if items.count == 1,
           let item = items.first,
           let quickProgress = try await performSingleAtomicMoveIfPossible(
               item: item,
               destination: destination,
               progress: progress,
               memorized: &memorized
           )
        {
            return quickProgress
        }
        showPanel(progress: progress, itemCount: items.count, operation: "move")
        for (index, item) in items.enumerated() {
            guard !progress.isCancelled else { break }
            let remaining = items.count - index
            let (target, skip, stop) = try await resolveConflictIfNeeded(
                source: item, destination: destination, operation: .move, remaining: remaining, memorized: &memorized)
            if stop { break }
            if skip {
                progress.fileSkipped(name: item.lastPathComponent)
                continue
            }
            progress.setCurrentFile(item.lastPathComponent)
            if await tryAtomicMove(from: item, to: target) {
                progress.fileCompleted(name: item.lastPathComponent, success: true)
            } else if isDirectory(url: item) {
                _ = await executeOpaqueDirectory(
                    source: item, target: target,
                    size: fileSize(url: item), operation: .move, progress: progress)
            } else {
                let plan = await buildPlan(items: [item], destination: destination)
                try await executeFewLarge(plan: plan, operation: .move, progress: progress)
            }
        }
        progress.complete()
        return progress
    }

    private func performSingleAtomicMoveIfPossible(
        item: URL,
        destination: URL,
        progress: FileOpProgress,
        memorized: inout ConflictResolution?
    ) async throws -> FileOpProgress? {
        let (target, skip, stop) = try await resolveConflictIfNeeded(
            source: item,
            destination: destination,
            operation: .move,
            remaining: 1,
            memorized: &memorized
        )
        if stop {
            progress.complete()
            return progress
        }
        if skip {
            progress.fileSkipped(name: item.lastPathComponent)
            progress.complete()
            return progress
        }
        guard await tryAtomicMove(from: item, to: target) else {
            return nil
        }
        progress.fileCompleted(name: item.lastPathComponent, success: true)
        progress.complete()
        return progress
    }



    func tryAtomicMove(from source: URL, to target: URL) async -> Bool {
        await Task.detached(priority: .userInitiated) {
            Self.performSameVolumeMove(from: source, to: target)
        }.value
    }



    nonisolated static func performSameVolumeMove(from source: URL, to target: URL) -> Bool {
        guard isSameVolume(source: source, target: target) else { return false }
        do {
            try FileManager.default.moveItem(at: source, to: target)
            return true
        } catch {
            return false
        }
    }



    nonisolated static func isSameVolume(source: URL, target: URL) -> Bool {
        let sourceVolume = try? source.resourceValues(forKeys: [.volumeIdentifierKey]).volumeIdentifier
        let targetVolume = try? target.deletingLastPathComponent().resourceValues(forKeys: [.volumeIdentifierKey]).volumeIdentifier
        guard let sourceVolume, let targetVolume else { return false }
        return sourceVolume.isEqual(targetVolume)
    }
}
