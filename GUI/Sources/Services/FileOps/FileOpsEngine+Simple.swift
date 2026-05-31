// FileOpsEngine+Simple.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 14.05.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Simple strategy — sequential copy/move for small batches (< 10 files, < 50 MB).

import Foundation

// MARK: - Strategy: Simple

extension FileOpsEngine {

    func executeSimple(plan: FileOpPlan, operation: FileOpType, progress: FileOpProgress) async throws {
        createDirectoryStructure(plan: plan)
        var memorized: ConflictResolution? = nil
        for (index, item) in plan.items.enumerated() {
            guard !progress.isCancelled else { break }
            let remaining = plan.items.count - index
            let (target, skip, stop) = try await resolveConflictIfNeeded(
                source: item, destination: plan.destination, operation: operation, remaining: remaining, memorized: &memorized)
            if stop { break }
            if skip {
                progress.fileSkipped(name: item.lastPathComponent)
                continue
            }
            progress.setCurrentFile(item.lastPathComponent)
            let result = await Task.detached(priority: .userInitiated) {
                Self.performIO(from: item, to: target, operation: operation)
            }.value
            if result.succeeded {
                progress.fileCompleted(name: item.lastPathComponent, success: true)
                progress.add(bytes: result.bytes)
            } else if let diagnostic = result.diagnostic {
                recordFailure(diagnostic, progress: progress)
            }
        }
    }



    nonisolated static func performIO(from source: URL, to target: URL, operation: FileOpType) -> IOResult {
        if AppState.isRemotePath(source) || AppState.isRemotePath(target) {
            return .fail(
                FileOperationDiagnosticInfo(
                    title: "\(operation.title) Failed",
                    summary: "Remote URLs are not supported by FileOpsEngine.",
                    details: "Operation: \(operation.title)\nPath: \(source.path)\nTarget: \(target.path)\nReason: Remote URLs not supported in FileOpsEngine",
                    path: source.path,
                    progressMessage: "\(source.lastPathComponent): remote URLs not supported"
                )
            )
        }
        if operation != .delete, let diagnostic = validateWritableDestination(source: source, target: target, operation: operation) {
            return .fail(diagnostic)
        }
        let fm = FileManager.default
        do {
            switch operation {
            case .copy: try fm.copyItem(at: source, to: target)
            case .move: try fm.moveItem(at: source, to: target)
            case .delete: try fm.removeItem(at: source)
            }
            let size = Int64((try? source.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
            return .ok(size)
        } catch {
            return .fail(FileOperationDiagnostics.make(operation: operation, source: source, target: target, error: error))
        }
    }

    // MARK: - Destination Preflight
    nonisolated private static func validateWritableDestination(
        source: URL,
        target: URL,
        operation: FileOpType
    ) -> FileOperationDiagnosticInfo? {
        let parent = target.deletingLastPathComponent()
        guard parent.isFileURL else { return nil }
        guard FileManager.default.fileExists(atPath: parent.path) else {
            return FileOperationDiagnostics.makeUnwritableDestination(operation: operation, source: source, target: target, reason: "Destination folder does not exist.")
        }
        guard FileManager.default.isWritableFile(atPath: parent.path) else {
            return FileOperationDiagnostics.makeUnwritableDestination(operation: operation, source: source, target: target, reason: "Destination folder is not writable.")
        }
        return nil
    }
}
