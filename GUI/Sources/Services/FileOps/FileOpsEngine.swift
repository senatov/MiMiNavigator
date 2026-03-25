// FileOpsEngine.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 11.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Unified async engine for copy/move/delete.
//   Clean Code: small methods, single responsibility, no duplication.

import Foundation

// MARK: - File Operations Engine

@MainActor
final class FileOpsEngine {

    static let shared = FileOpsEngine()

    /// Result of an off-MainActor file I/O operation
    struct IOResult: Sendable {
        let bytes: Int64
        let error: String?
        var succeeded: Bool { error == nil }
        static func ok(_ bytes: Int64) -> IOResult { IOResult(bytes: bytes, error: nil) }
        static func fail(_ msg: String) -> IOResult { IOResult(bytes: 0, error: msg) }
    }

    private let panel = FileOpProgressPanel.shared
    private let fm = FileManager.default
    private let maxConcurrency = 5

    private init() {
        log.debug("[FileOpsEngine] init")
    }
}

// MARK: - Public API

extension FileOpsEngine {
    
    /// Copy items to destination
    @discardableResult
    func copy(items: [URL], to destination: URL) async throws -> FileOpProgress {
        log.info("[FileOpsEngine] copy \(items.count) items → \(destination.path)")
        let plan = await buildPlan(items: items, destination: destination)
        return try await executeWithPanel(plan: plan, operation: .copy)
    }
    
    /// Move items to destination (atomic when possible)
    @discardableResult
    func move(items: [URL], to destination: URL) async throws -> FileOpProgress {
        log.info("[FileOpsEngine] move \(items.count) items → \(destination.path)")
        return try await performMove(items: items, to: destination)
    }
    
    /// Delete items to Trash
    @discardableResult
    func delete(items: [URL]) async throws -> FileOpProgress {
        log.info("[FileOpsEngine] delete \(items.count) items")
        return try await performDelete(items: items)
    }
}

// MARK: - Move Implementation

private extension FileOpsEngine {
    
    func performMove(items: [URL], to destination: URL) async throws -> FileOpProgress {
        let progress = createProgress(items: items, type: .move, destination: destination)
        showPanel(progress: progress, itemCount: items.count, operation: "move")
        
        let failedItems = await tryAtomicMoves(items: items, to: destination, progress: progress)
        
        if !failedItems.isEmpty {
            try await handleCrossVolumeMove(items: failedItems, to: destination, progress: progress)
        }
        
        progress.complete()
        return progress
    }
    
    func tryAtomicMoves(items: [URL], to destination: URL, progress: FileOpProgress) async -> [URL] {
        var failedItems: [URL] = []
        
        for item in items {
            let target = UniqueNameGen.resolve(name: item.lastPathComponent, in: destination)
            progress.setCurrentFile(item.lastPathComponent)
            
            if tryAtomicMove(from: item, to: target) {
                progress.fileCompleted(name: item.lastPathComponent, success: true)
            } else {
                failedItems.append(item)
            }
        }
        return failedItems
    }
    
    func tryAtomicMove(from source: URL, to target: URL) -> Bool {
        do {
            try fm.moveItem(at: source, to: target)
            log.debug("[FileOpsEngine] atomic move OK: \(source.lastPathComponent)")
            return true
        } catch {
            log.debug("[FileOpsEngine] atomic move failed: \(source.lastPathComponent)")
            return false
        }
    }
    
    func handleCrossVolumeMove(items: [URL], to destination: URL, progress: FileOpProgress) async throws {
        let plan = await buildPlan(items: items, destination: destination)
        try await executeFewLarge(plan: plan, operation: .move, progress: progress)
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
        do {
            try fm.trashItem(at: url, resultingItemURL: nil)
            let size = fileSize(url: url)
            progress.fileCompleted(name: url.lastPathComponent, success: true)
            progress.add(bytes: size)
        } catch {
            progress.fileCompleted(name: url.lastPathComponent, success: false, error: error.localizedDescription)
            log.error("[FileOpsEngine] trash failed: \(url.lastPathComponent)")
        }
    }
}


// MARK: - Panel & Progress Helpers

private extension FileOpsEngine {
    
    func createProgress(items: [URL], type: FileOpType, destination: URL?) -> FileOpProgress {
        FileOpProgress(totalFiles: items.count, totalBytes: 0, type: type, destination: destination)
    }
    
    func shouldShowPanel(items: [URL]) -> Bool {
        items.count > 1 || items.contains { isDirectory(url: $0) }
    }
    
    func showPanel(progress: FileOpProgress, itemCount: Int, operation: String = "items") {
        log.info("[FileOpsEngine] scheduling panel for \(itemCount) \(operation)")

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 200_000_000) // 200 ms delay

            // Do not show if already completed
            guard !progress.isCompleted else { return }

            panel.hide()
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
        return FileOpPlan(
            items: items,
            destination: destination,
            strategy: strategy,
            totalBytes: scan.totalBytes,
            fileCount: scan.fileCount,
            flatList: scan.flatList
        )
    }
    
    func executeWithPanel(plan: FileOpPlan, operation: FileOpType) async throws -> FileOpProgress {
        let progress = FileOpProgress(
            totalFiles: plan.fileCount,
            totalBytes: plan.totalBytes,
            type: operation,
            destination: plan.destination
        )
        
        showPanel(progress: progress, itemCount: plan.fileCount, operation: String(describing: operation))
        defer { progress.complete() }
        
        try await executeStrategy(plan: plan, operation: operation, progress: progress)
        return progress
    }
    
    func shouldShowPanelForPlan(_ plan: FileOpPlan) -> Bool {
        plan.fileCount > 1 || plan.totalBytes > 1_000_000 || plan.items.contains { isDirectory(url: $0) }
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


// MARK: - Strategy: Simple (sequential)

private extension FileOpsEngine {
    
    func executeSimple(plan: FileOpPlan, operation: FileOpType, progress: FileOpProgress) async throws {
        for item in plan.items {
            guard !progress.isCancelled else { break }
            progress.setCurrentFile(item.lastPathComponent)
            let destination = plan.destination
            let result = await Task.detached(priority: .userInitiated) {
                Self.performSingleItemIO(item: item, destination: destination, operation: operation)
            }.value
            if result.succeeded {
                progress.fileCompleted(name: item.lastPathComponent, success: true)
                progress.add(bytes: result.bytes)
            } else {
                progress.fileCompleted(name: item.lastPathComponent, success: false, error: result.error)
            }
        }
    }

    /// Single item I/O off MainActor.
    nonisolated static func performSingleItemIO(item: URL, destination: URL, operation: FileOpType) -> IOResult {
        let fm = FileManager.default
        let target = UniqueNameGen.resolve(name: item.lastPathComponent, in: destination)
        do {
            switch operation {
            case .copy: try fm.copyItem(at: item, to: target)
            case .move: try fm.moveItem(at: item, to: target)
            }
            let size = Int64((try? item.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
            return .ok(size)
        } catch {
            return .fail(error.localizedDescription)
        }
    }

    func processItem(item: URL, to destination: URL, operation: FileOpType, progress: FileOpProgress) throws {
        progress.setCurrentFile(item.lastPathComponent)
        let target = UniqueNameGen.resolve(name: item.lastPathComponent, in: destination)
        do {
            try performFileOperation(from: item, to: target, operation: operation)
            progress.fileCompleted(name: item.lastPathComponent, success: true)
            progress.add(bytes: fileSize(url: item))
        } catch {
            progress.fileCompleted(name: item.lastPathComponent, success: false, error: error.localizedDescription)
        }
    }
    
    func performFileOperation(from source: URL, to target: URL, operation: FileOpType) throws {
        switch operation {
        case .copy: try fm.copyItem(at: source, to: target)
        case .move: try fm.moveItem(at: source, to: target)
        }
    }
}


// MARK: - Strategy: ManySmall (parallel)

private extension FileOpsEngine {
    
    func executeManySmall(plan: FileOpPlan, operation: FileOpType, progress: FileOpProgress) async throws {
        createDirectoryStructure(plan: plan)
        try await processFilesInParallel(plan: plan, operation: operation, progress: progress)
        
        if operation == .move {
            cleanupEmptyDirs(plan: plan)
        }
    }
    
    func createDirectoryStructure(plan: FileOpPlan) {
        for entry in plan.flatList where entry.isDirectory {
            let targetDir = plan.destination.appendingPathComponent(entry.relativePath)
            try? fm.createDirectory(at: targetDir, withIntermediateDirectories: true)
        }
    }
    
    func processFilesInParallel(plan: FileOpPlan, operation: FileOpType, progress: FileOpProgress) async throws {
        let fileEntries = plan.flatList.filter { !$0.isDirectory }
        let destination = plan.destination
        let maxConc = maxConcurrency
        try await withThrowingTaskGroup(of: Void.self) { group in
            var running = 0
            for entry in fileEntries {
                guard !progress.isCancelled else { break }
                if running >= maxConc {
                    try await group.next()
                    running -= 1
                }
                group.addTask(priority: .userInitiated) {
                    let result = Self.performFileEntryIO(entry: entry, destination: destination, operation: operation)
                    await MainActor.run {
                        if result.succeeded {
                            progress.fileCompleted(name: entry.url.lastPathComponent, success: true)
                            progress.add(bytes: result.bytes)
                        } else {
                            progress.fileCompleted(name: entry.url.lastPathComponent, success: false, error: result.error)
                        }
                    }
                }
                running += 1
            }
            try await group.waitForAll()
        }
    }
    
    func processFileEntry(entry: DirScanResult.FileEntry, destination: URL, operation: FileOpType, progress: FileOpProgress) {
        progress.setCurrentFile(entry.url.lastPathComponent)
        let targetURL = UniqueNameGen.resolve(name: entry.relativePath, in: destination)
        ensureParentDirectory(for: targetURL)
        do {
            try performFileOperation(from: entry.url, to: targetURL, operation: operation)
            progress.fileCompleted(name: entry.url.lastPathComponent, success: true)
            progress.add(bytes: entry.size)
        } catch {
            progress.fileCompleted(name: entry.url.lastPathComponent, success: false, error: error.localizedDescription)
        }
    }

    /// Perform file I/O off MainActor — eliminates QoS priority inversion.
    nonisolated static func performFileEntryIO(
        entry: DirScanResult.FileEntry,
        destination: URL,
        operation: FileOpType
    ) -> IOResult {
        let fm = FileManager.default
        let targetURL = UniqueNameGen.resolve(name: entry.relativePath, in: destination)
        let parentDir = targetURL.deletingLastPathComponent()
        if !fm.fileExists(atPath: parentDir.path) {
            try? fm.createDirectory(at: parentDir, withIntermediateDirectories: true)
        }
        do {
            switch operation {
            case .copy: try fm.copyItem(at: entry.url, to: targetURL)
            case .move: try fm.moveItem(at: entry.url, to: targetURL)
            }
            return .ok(entry.size)
        } catch {
            return .fail(error.localizedDescription)
        }
    }

    func ensureParentDirectory(for url: URL) {
        let parentDir = url.deletingLastPathComponent()
        if !fm.fileExists(atPath: parentDir.path) {
            try? fm.createDirectory(at: parentDir, withIntermediateDirectories: true)
        }
    }
}


// MARK: - Strategy: FewLarge (streaming)

private extension FileOpsEngine {
    
    func executeFewLarge(plan: FileOpPlan, operation: FileOpType, progress: FileOpProgress) async throws {
        createDirectoryStructure(plan: plan)
        
        for entry in plan.flatList where !entry.isDirectory {
            guard !progress.isCancelled else { break }
            try await processLargeFile(entry: entry, destination: plan.destination, operation: operation, progress: progress)
        }
        
        if operation == .move {
            cleanupEmptyDirs(plan: plan)
        }
    }
    
    func processLargeFile(entry: DirScanResult.FileEntry, destination: URL, operation: FileOpType, progress: FileOpProgress) async throws {
        progress.setCurrentFile(entry.url.lastPathComponent)
        let targetURL = UniqueNameGen.resolve(name: entry.relativePath, in: destination)
        ensureParentDirectory(for: targetURL)
        
        do {
            if operation == .move && tryAtomicMove(from: entry.url, to: targetURL) {
                progress.fileCompleted(name: entry.url.lastPathComponent, success: true)
                progress.add(bytes: entry.size)
                return
            }
            
            try await streamCopy(from: entry.url, to: targetURL, progress: progress)
            
            if operation == .move {
                try fm.removeItem(at: entry.url)
            }
            progress.fileCompleted(name: entry.url.lastPathComponent, success: true)
        } catch {
            progress.fileCompleted(name: entry.url.lastPathComponent, success: false, error: error.localizedDescription)
        }
    }
}


// MARK: - Stream Copy

private extension FileOpsEngine {
    
    func streamCopy(from source: URL, to destination: URL, progress: FileOpProgress) async throws {
        let result = await Task.detached(priority: .userInitiated) {
            Self.performStreamCopy(from: source, to: destination)
        }.value
        switch result {
        case .success(let totalBytes):
            progress.add(bytes: totalBytes)
        case .failure(let error):
            throw error
        }
    }

    /// Pure I/O — runs off MainActor on background thread.
    nonisolated static func performStreamCopy(from source: URL, to destination: URL) -> Result<Int64, FileOpError> {
        guard let input = InputStream(url: source) else {
            return .failure(.fileNotFound(source.path))
        }
        guard let output = OutputStream(url: destination, append: false) else {
            return .failure(.invalidDest(destination.path))
        }
        input.open()
        output.open()
        defer { input.close(); output.close() }
        let bufSize = 256 * 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufSize)
        defer { buffer.deallocate() }
        var totalCopied: Int64 = 0
        while true {
            let bytesRead = input.read(buffer, maxLength: bufSize)
            if bytesRead < 0 { return .failure(.readFailed(source.path)) }
            if bytesRead == 0 { break }
            let written = output.write(buffer, maxLength: bytesRead)
            if written < 0 { return .failure(.writeFailed(source.path)) }
            totalCopied += Int64(written)
        }
        return .success(totalCopied)
    }
}


// MARK: - Cleanup

private extension FileOpsEngine {
    
    func cleanupEmptyDirs(plan: FileOpPlan) {
        let dirs = sortDirectoriesByDepth(plan: plan)
        for dir in dirs {
            removeIfEmpty(url: dir.url)
        }
    }
    
    func sortDirectoriesByDepth(plan: FileOpPlan) -> [DirScanResult.FileEntry] {
        plan.flatList
            .filter { $0.isDirectory }
            .sorted { $0.relativePath.components(separatedBy: "/").count > $1.relativePath.components(separatedBy: "/").count }
    }
    
    func removeIfEmpty(url: URL) {
        let contents = (try? fm.contentsOfDirectory(atPath: url.path)) ?? []
        if contents.isEmpty {
            try? fm.removeItem(at: url)
        }
    }
}
