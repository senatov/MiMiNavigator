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
        showPanel(progress: progress, itemCount: items.count, operation: "move")
        var memorized: ConflictResolution? = nil
        for (index, item) in items.enumerated() {
            guard !progress.isCancelled else { break }
            let remaining = items.count - index
            let (target, skip, stop) = try await resolveConflictIfNeeded(
                source: item, destination: destination, remaining: remaining, memorized: &memorized)
            if stop { break }
            if skip {
                progress.fileSkipped(name: item.lastPathComponent)
                continue
            }
            progress.setCurrentFile(item.lastPathComponent)
            if await tryAtomicMove(from: item, to: target) {
                progress.fileCompleted(name: item.lastPathComponent, success: true)
            } else {
                let plan = await buildPlan(items: [item], destination: destination)
                try await executeFewLarge(plan: plan, operation: .move, progress: progress)
            }
        }
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
