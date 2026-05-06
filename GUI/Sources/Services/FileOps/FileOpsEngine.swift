// FileOpsEngine.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 11.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Unified async engine for copy/move/delete.
//   Now with conflict resolution dialog support (Windows-style).

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

    private let panel = FileOpProgressPanel.shared
    private let fm = FileManager.default
    private let maxConcurrency = 5

    /// conflict handler — set by CntMenuCoord at init.
    /// Called on MainActor when destination file already exists.
    /// Returns BatchConflictDecision (resolution + applyToAll flag).
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


// MARK: - Conflict Resolution

private extension FileOpsEngine {

    /// Check if target exists, ask user what to do.
    /// Returns (resolvedTargetURL, shouldSkip). If shouldSkip=true, caller must skip this file.
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
            // no handler — fallback to keepBoth (silent rename)
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


// MARK: - Move Implementation

private extension FileOpsEngine {

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
                // cross-volume fallback
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
        do { try FileManager.default.moveItem(at: source, to: target); return true } catch { return false }
    }

    nonisolated static func isSameVolume(source: URL, target: URL) -> Bool {
        let sourceVolume = try? source.resourceValues(forKeys: [.volumeIdentifierKey]).volumeIdentifier
        let targetVolume = try? target.deletingLastPathComponent().resourceValues(forKeys: [.volumeIdentifierKey]).volumeIdentifier
        guard let sourceVolume, let targetVolume else { return false }
        return sourceVolume.isEqual(targetVolume)
    }
}


// MARK: - Delete Implementation

private extension FileOpsEngine {

    func performDelete(items: [URL]) async throws -> FileOpProgress {
        let totalSize = calculateTotalSize(items: items)
        let progress = FileOpProgress(totalFiles: items.count, totalBytes: totalSize, type: .copy, destination: nil)
        showPanel(progress: progress, itemCount: items.count, operation: "delete")
        defer { progress.complete() }
        for url in items {
            guard !progress.isCancelled else { break }
            trashItem(url: url, progress: progress)
        }
        return progress
    }

    func trashItem(url: URL, progress: FileOpProgress) {
        progress.setCurrentFile(url.lastPathComponent)
        if AppLogger.isProtectedLogFile(url) {
            recordFailure(
                FileOperationDiagnostics.makeProtectedDelete(source: url),
                progress: progress
            )
            return
        }
        do {
            try fm.trashItem(at: url, resultingItemURL: nil)
            progress.fileCompleted(name: url.lastPathComponent, success: true)
            progress.add(bytes: fileSize(url: url))
        } catch {
            recordFailure(
                FileOperationDiagnostics.makeDelete(source: url, error: error),
                progress: progress
            )
        }
    }
}


// MARK: - Panel & Progress Helpers

private extension FileOpsEngine {

    func createProgress(items: [URL], type: FileOpType, destination: URL?) -> FileOpProgress {
        FileOpProgress(totalFiles: items.count, totalBytes: 0, type: type, destination: destination)
    }

    func showPanel(progress: FileOpProgress, itemCount: Int, operation: String = "items") {
        log.info("[FileOpsEngine] scheduling panel for \(itemCount) \(operation)")
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard !progress.isCompleted, !progress.isCancelled else { return }
            panel.hideKeepingSuspendState()
            panel.show(progress: progress)
        }
    }

    func isDirectory(url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
    }

    func fileSize(url: URL) -> Int64 {
        Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
    }

    func calculateTotalSize(items: [URL]) -> Int64 {
        items.reduce(0) { $0 + fileSize(url: $1) }
    }
}


// MARK: - Plan & Execute

private extension FileOpsEngine {

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


// MARK: - Strategy: Simple

private extension FileOpsEngine {

    func executeSimple(plan: FileOpPlan, operation: FileOpType, progress: FileOpProgress) async throws {
        var memorized: ConflictResolution? = nil
        for (index, item) in plan.items.enumerated() {
            guard !progress.isCancelled else { break }
            let remaining = plan.items.count - index

            let (target, skip, stop) = try await resolveConflictIfNeeded(
                source: item, destination: plan.destination, remaining: remaining, memorized: &memorized)
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
        let fm = FileManager.default
        do {
            switch operation {
            case .copy: try fm.copyItem(at: source, to: target)
            case .move: try fm.moveItem(at: source, to: target)
            }
            let size = Int64((try? source.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
            return .ok(size)
        } catch {
            return .fail(FileOperationDiagnostics.make(operation: operation, source: source, target: target, error: error))
        }
    }
}


// MARK: - Strategy: ManySmall (parallel with conflict check on MainActor)

private extension FileOpsEngine {

    func executeManySmall(plan: FileOpPlan, operation: FileOpType, progress: FileOpProgress) async throws {
        createDirectoryStructure(plan: plan)
        // conflict resolution must happen on MainActor sequentially before dispatch
        var memorized: ConflictResolution? = nil
        let fileEntries = plan.flatList.filter { !$0.isDirectory }

        // pre-resolve all conflicts on MainActor, then dispatch IO in parallel
        struct ResolvedEntry: Sendable {
            let source: URL
            let target: URL
            let size: Int64
        }

        var resolved: [ResolvedEntry] = []
        for (index, entry) in fileEntries.enumerated() {
            guard !progress.isCancelled else { break }
            let remaining = fileEntries.count - index
            let targetDir = plan.destination.appendingPathComponent(
                (entry.relativePath as NSString).deletingLastPathComponent)
            let targetURL = targetDir.appendingPathComponent(entry.url.lastPathComponent)

            if fm.fileExists(atPath: targetURL.path) {
                let (finalTarget, skip, stop) = try await resolveConflictIfNeeded(
                    source: entry.url, destination: targetDir, remaining: remaining, memorized: &memorized)
                if stop { break }
                if skip { progress.fileSkipped(name: entry.url.lastPathComponent); continue }
                resolved.append(ResolvedEntry(source: entry.url, target: finalTarget, size: entry.size))
            } else {
                resolved.append(ResolvedEntry(source: entry.url, target: targetURL, size: entry.size))
            }
        }

        // now execute resolved entries in parallel — no more conflict checks needed
        try await withThrowingTaskGroup(of: Void.self) { group in
            var running = 0
            for entry in resolved {
                guard !progress.isCancelled else { break }
                if running >= maxConcurrency {
                    try await group.next()
                    running -= 1
                }
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

        if operation == .move { cleanupEmptyDirs(plan: plan) }
    }

    func createDirectoryStructure(plan: FileOpPlan) {
        for entry in plan.flatList where entry.isDirectory {
            let targetDir = plan.destination.appendingPathComponent(entry.relativePath)
            try? fm.createDirectory(at: targetDir, withIntermediateDirectories: true)
        }
    }
}


// MARK: - Strategy: FewLarge

private extension FileOpsEngine {

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
                    source: entry.url, destination: targetDir, remaining: remaining, memorized: &memorized)
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
                try await streamCopy(from: entry.url, to: finalTarget, progress: progress)
                if operation == .move { try fm.removeItem(at: entry.url) }
                progress.fileCompleted(name: entry.url.lastPathComponent, success: true)
            } catch {
                recordFailure(
                    FileOperationDiagnostics.make(operation: operation, source: entry.url, target: finalTarget, error: error),
                    progress: progress
                )
            }
        }

        if operation == .move { cleanupEmptyDirs(plan: plan) }
    }
}


// MARK: - Stream Copy

private extension FileOpsEngine {

    func streamCopy(from source: URL, to destination: URL, progress: FileOpProgress) async throws {
        let result = await Task.detached(priority: .userInitiated) {
            Self.performStreamCopy(from: source, to: destination)
        }.value
        switch result {
        case .success(let totalBytes): progress.add(bytes: totalBytes)
        case .failure(let error): throw error
        }
    }

    nonisolated static func performStreamCopy(from source: URL, to destination: URL) -> Result<Int64, FileOpError> {
        guard let input = InputStream(url: source) else { return .failure(.fileNotFound(source.path)) }
        guard let output = OutputStream(url: destination, append: false) else { return .failure(.invalidDest(destination.path)) }
        input.open(); output.open()
        defer { input.close(); output.close() }
        let bufSize = 256 * 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufSize)
        defer { buffer.deallocate() }
        var total: Int64 = 0
        while true {
            let read = input.read(buffer, maxLength: bufSize)
            if read < 0 { return .failure(.readFailed(source.path)) }
            if read == 0 { break }
            let written = output.write(buffer, maxLength: read)
            if written < 0 { return .failure(.writeFailed(source.path)) }
            total += Int64(written)
        }
        return .success(total)
    }
}


// MARK: - Cleanup

private extension FileOpsEngine {
    func recordFailure(_ diagnostic: FileOperationDiagnosticInfo, progress: FileOpProgress) {
        let shouldPresentModal = progress.errors.isEmpty
        let fileName = URL(fileURLWithPath: diagnostic.path).lastPathComponent
        progress.fileCompleted(name: fileName, success: false, error: diagnostic.progressMessage)
        log.error("[FileOpsEngine] \(diagnostic.details.replacingOccurrences(of: "\n", with: " | "))")
        if shouldPresentModal {
            FileOperationDiagnosticPresenter.shared.show(diagnostic)
        }
    }

    func cleanupEmptyDirs(plan: FileOpPlan) {
        plan.flatList.filter(\.isDirectory)
            .sorted { $0.relativePath.components(separatedBy: "/").count > $1.relativePath.components(separatedBy: "/").count }
            .forEach { entry in
                let contents = (try? fm.contentsOfDirectory(atPath: entry.url.path)) ?? []
                if contents.isEmpty { try? fm.removeItem(at: entry.url) }
            }
    }
}
