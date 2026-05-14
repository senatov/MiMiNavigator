// FileOpsEngine.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 11.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Unified async engine for copy/move/delete.
//   Strategy dispatch + public API. Implementations split into extensions.

import Foundation

// MARK: - File Operations Engine

@MainActor
final class FileOpsEngine {

    static let shared = FileOpsEngine()

    struct IOResult: Sendable {
        let bytes: Int64
        let diagnostic: FileOperationDiagnosticInfo?
        var succeeded: Bool { diagnostic == nil }
        static func ok(_ bytes: Int64) -> IOResult { IOResult(bytes: bytes, diagnostic: nil) }
        static func fail(_ diagnostic: FileOperationDiagnosticInfo) -> IOResult { IOResult(bytes: 0, diagnostic: diagnostic) }
    }

    let panel = FileOpProgressPanel.shared
    let fm = FileManager.default
    let maxConcurrency = 5

    /// conflict handler — set by CntMenuCoord at init.
    /// Called on MainActor when destination file already exists.
    var conflictHandler: ((FileConflictInfo, Int) async -> BatchConflictDecision)?

    private init() {
        log.debug("[FileOpsEngine] init")
    }
}


// MARK: - Public API

extension FileOpsEngine {

    @discardableResult
    func copy(items: [URL], to destination: URL) async throws -> FileOpProgress {
        log.info("[FileOpsEngine] copy \(items.count) items → \(destination.path)")
        let plan = await buildPlan(items: items, destination: destination)
        return try await executeWithPanel(plan: plan, operation: .copy)
    }



    @discardableResult
    func move(items: [URL], to destination: URL) async throws -> FileOpProgress {
        log.info("[FileOpsEngine] move \(items.count) items → \(destination.path)")
        return try await performMove(items: items, to: destination)
    }



    @discardableResult
    func delete(items: [URL]) async throws -> FileOpProgress {
        log.info("[FileOpsEngine] delete \(items.count) items")
        return try await performDelete(items: items)
    }
}


// MARK: - Plan & Execute

extension FileOpsEngine {

    func buildPlan(items: [URL], destination: URL) async -> FileOpPlan {
        let scan = await DirSizeCalculator.scan(items)
        let strategy = FileOpStrategy.detect(scan: scan)
        let executableItems = strategy == .simple
            ? scan.flatList.filter { !$0.isDirectory }.map(\.url)
            : items
        return FileOpPlan(
            items: executableItems, destination: destination, strategy: strategy,
            totalBytes: scan.totalBytes, fileCount: scan.fileCount, flatList: scan.flatList)
    }



    func executeWithPanel(plan: FileOpPlan, operation: FileOpType) async throws -> FileOpProgress {
        let progress = FileOpProgress(
            totalFiles: plan.fileCount, totalBytes: plan.totalBytes,
            type: operation, destination: plan.destination)
        showPanel(progress: progress, itemCount: plan.fileCount, operation: String(describing: operation))
        defer { progress.complete() }
        try await executeStrategy(plan: plan, operation: operation, progress: progress)
        return progress
    }



    func executeStrategy(plan: FileOpPlan, operation: FileOpType, progress: FileOpProgress) async throws {
        switch plan.strategy {
        case .simple:
            try await executeSimple(plan: plan, operation: operation, progress: progress)
        case .manySmall:
            try await executeManySmall(plan: plan, operation: operation, progress: progress)
        case .fewLarge:
            try await executeFewLarge(plan: plan, operation: operation, progress: progress)
        }
    }
}
