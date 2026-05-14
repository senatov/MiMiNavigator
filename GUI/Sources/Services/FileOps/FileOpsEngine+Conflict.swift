// FileOpsEngine+Conflict.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 14.05.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Conflict resolution logic — ask user what to do when target exists.

import Foundation

// MARK: - Conflict Resolution

extension FileOpsEngine {

    /// Check if target exists, ask user what to do.
    /// Returns (resolvedTargetURL, shouldSkip, shouldStop).
    /// Updates `memorized` in-out param when user checks "apply to all".
    func resolveConflictIfNeeded(
        source: URL,
        destination: URL,
        remaining: Int,
        memorized: inout ConflictResolution?
    ) async throws -> (target: URL, skip: Bool, stop: Bool) {
        let target = destination.appendingPathComponent(source.lastPathComponent)
        guard fm.fileExists(atPath: target.path) else {
            return (target, false, false)
        }
        let resolution: ConflictResolution
        if let memo = memorized {
            resolution = memo
            log.debug("[FileOpsEngine] auto-resolved '\(source.lastPathComponent)' → \(memo)")
        } else if let handler = conflictHandler {
            let conflict = FileConflictInfo(source: source, target: target)
            panel.suspendForUserDecision()
            defer { panel.resumeAfterUserDecision() }
            let decision = await handler(conflict, remaining)
            resolution = decision.resolution
            if decision.applyToAll {
                memorized = resolution
                log.info("[FileOpsEngine] 'apply to all' → \(resolution)")
            }
        } else {
            return (UniqueNameGen.resolve(name: source.lastPathComponent, in: destination), false, false)
        }
        switch resolution {
        case .stop:
            return (target, false, true)
        case .skip:
            return (target, true, false)
        case .keepBoth:
            return (UniqueNameGen.resolve(name: source.lastPathComponent, in: destination), false, false)
        case .replace:
            if fm.fileExists(atPath: target.path) {
                try fm.removeItem(at: target)
            }
            return (target, false, false)
        }
    }
}
