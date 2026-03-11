// FileOpsEngine.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 11.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Unified async engine for copy/move/delete — replaces 4 scattered implementations.
//   Supports 3 strategies: simple (sequential), manySmall (parallel TaskGroup), fewLarge (stream-copy).

import Foundation

// MARK: - File Operations Engine
@MainActor
final class FileOpsEngine {

    static let shared = FileOpsEngine()

    private let panel = FileOpProgressPanel.shared
    private let maxConcurrency = 5
    private let chunkSize = 256 * 1024  // 256 KB

    private init() {
        log.debug("[FileOpsEngine] init")
    }

    // MARK: - Public API: Copy

    /// Copy items to destination. Auto-detects strategy.
    /// Returns once all items are processed (or cancelled).
    @discardableResult
    func copy(items: [URL], to destination: URL) async throws -> FileOpProgress {
        log.info("[FileOpsEngine] copy \(items.count) items → \(destination.path)")
        let plan = await buildPlan(items: items, destination: destination)
        return try await execute(plan: plan, operation: .copy)
    }

    // MARK: - Public API: Move

    /// Move items to destination. Auto-detects strategy.
    @discardableResult
    func move(items: [URL], to destination: URL) async throws -> FileOpProgress {
        log.info("[FileOpsEngine] move \(items.count) items → \(destination.path)")
        let plan = await buildPlan(items: items, destination: destination)
        return try await execute(plan: plan, operation: .move)
    }

    // MARK: - Public API: Delete

    /// Trash items. Always sequential (macOS Trash API is not parallelizable).
    @discardableResult
    func delete(items: [URL]) async throws -> FileOpProgress {
        log.info("[FileOpsEngine] delete \(items.count) items")
        let totalSize = items.reduce(Int64(0)) { sum, url in
            sum + ((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0)
        }
        let progress = FileOpProgress(
            totalFiles: items.count,
            totalBytes: totalSize,
            type: .copy,  // reuse for display
            destination: nil
        )

        let showPanel = items.count > 5
        if showPanel { panel.show(progress: progress) }
        defer {
            progress.complete()
            if showPanel { panel.hide() }
        }

        let fm = FileManager.default
        for url in items {
            guard !progress.isCancelled else { break }
            progress.setCurrentFile(url.lastPathComponent)
            do {
                try fm.trashItem(at: url, resultingItemURL: nil)
                let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
                progress.fileCompleted(name: url.lastPathComponent, success: true)
                progress.add(bytes: size)
            } catch {
                progress.fileCompleted(name: url.lastPathComponent, success: false, error: error.localizedDescription)
                log.error("[FileOpsEngine] trash failed: \(url.lastPathComponent) — \(error.localizedDescription)")
            }
        }
        return progress
    }

    // MARK: - Plan

    private func buildPlan(items: [URL], destination: URL) async -> FileOpPlan {
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

    // MARK: - Execute

    private func execute(plan: FileOpPlan, operation: FileOpType) async throws -> FileOpProgress {
        let progress = FileOpProgress(
            totalFiles: plan.fileCount,
            totalBytes: plan.totalBytes,
            type: operation,
            destination: plan.destination
        )

        // Show panel for non-trivial operations
        let showPanel = plan.strategy != .simple
        if showPanel { panel.show(progress: progress) }
        defer {
            progress.complete()
            if showPanel { panel.hide() }
        }

        switch plan.strategy {
            case .simple:
                try await executeSimple(plan: plan, operation: operation, progress: progress)
            case .manySmall:
                try await executeManySmall(plan: plan, operation: operation, progress: progress)
            case .fewLarge:
                try await executeFewLarge(plan: plan, operation: operation, progress: progress)
        }

        return progress
    }

    // MARK: - Simple (sequential, no parallelism)

    private func executeSimple(plan: FileOpPlan, operation: FileOpType, progress: FileOpProgress) async throws {
        let fm = FileManager.default

        for item in plan.items {
            guard !progress.isCancelled else { break }
            progress.setCurrentFile(item.lastPathComponent)

            let target = UniqueNameGen.resolve(name: item.lastPathComponent, in: plan.destination)
            do {
                switch operation {
                    case .copy:
                        try fm.copyItem(at: item, to: target)
                    case .move:
                        try fm.moveItem(at: item, to: target)
                }
                let size = (try? item.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
                progress.fileCompleted(name: item.lastPathComponent, success: true)
                progress.add(bytes: size)
            } catch {
                progress.fileCompleted(name: item.lastPathComponent, success: false, error: error.localizedDescription)
            }
        }
    }

    // MARK: - ManySmall (parallel, up to 5 concurrent)

    private func executeManySmall(plan: FileOpPlan, operation: FileOpType, progress: FileOpProgress) async throws {
        let fm = FileManager.default
        let dest = plan.destination

        // First pass: create directory structure
        for entry in plan.flatList where entry.isDirectory {
            let targetDir = dest.appendingPathComponent(entry.relativePath)
            try? fm.createDirectory(at: targetDir, withIntermediateDirectories: true)
        }

        // Second pass: process files in parallel
        let fileEntries = plan.flatList.filter { !$0.isDirectory }

        try await withThrowingTaskGroup(of: Void.self) { group in
            var running = 0

            for entry in fileEntries {
                guard !progress.isCancelled else { break }

                if running >= maxConcurrency {
                    try await group.next()
                    running -= 1
                }

                group.addTask { @MainActor in
                    progress.setCurrentFile(entry.url.lastPathComponent)

                    let targetURL = UniqueNameGen.resolve(
                        name: entry.relativePath,
                        in: dest
                    )

                    // Ensure parent dir exists
                    let parentDir = targetURL.deletingLastPathComponent()
                    if !fm.fileExists(atPath: parentDir.path) {
                        try? fm.createDirectory(at: parentDir, withIntermediateDirectories: true)
                    }

                    do {
                        switch operation {
                            case .copy:
                                try fm.copyItem(at: entry.url, to: targetURL)
                            case .move:
                                try fm.moveItem(at: entry.url, to: targetURL)
                        }
                        progress.fileCompleted(name: entry.url.lastPathComponent, success: true)
                        progress.add(bytes: entry.size)
                    } catch {
                        progress.fileCompleted(
                            name: entry.url.lastPathComponent,
                            success: false,
                            error: error.localizedDescription
                        )
                    }
                }
                running += 1
            }

            try await group.waitForAll()
        }

        // For move: clean up empty source directories (bottom-up)
        if operation == .move {
            cleanupEmptyDirs(plan: plan, fm: fm)
        }
    }

    // MARK: - FewLarge (stream copy with byte-level progress)

    private func executeFewLarge(plan: FileOpPlan, operation: FileOpType, progress: FileOpProgress) async throws {
        let fm = FileManager.default
        let dest = plan.destination

        // Create directory structure
        for entry in plan.flatList where entry.isDirectory {
            let targetDir = dest.appendingPathComponent(entry.relativePath)
            try? fm.createDirectory(at: targetDir, withIntermediateDirectories: true)
        }

        let fileEntries = plan.flatList.filter { !$0.isDirectory }

        for entry in fileEntries {
            guard !progress.isCancelled else { break }
            progress.setCurrentFile(entry.url.lastPathComponent)

            let targetURL = UniqueNameGen.resolve(
                name: entry.relativePath,
                in: dest
            )

            // Ensure parent
            let parentDir = targetURL.deletingLastPathComponent()
            if !fm.fileExists(atPath: parentDir.path) {
                try? fm.createDirectory(at: parentDir, withIntermediateDirectories: true)
            }

            do {
                if operation == .move {
                    // Attempt rename first (instant if same volume)
                    do {
                        try fm.moveItem(at: entry.url, to: targetURL)
                        progress.fileCompleted(name: entry.url.lastPathComponent, success: true)
                        progress.add(bytes: entry.size)
                        continue
                    } catch {
                        // Cross-volume — fall through to stream copy + delete
                        log.debug("[FileOpsEngine] cross-volume move, streaming: \(entry.url.lastPathComponent)")
                    }
                }

                // Stream copy with chunked progress
                try await streamCopy(from: entry.url, to: targetURL, progress: progress)

                // For move: delete source after successful copy
                if operation == .move {
                    try fm.removeItem(at: entry.url)
                }

                progress.fileCompleted(name: entry.url.lastPathComponent, success: true)
            } catch {
                progress.fileCompleted(
                    name: entry.url.lastPathComponent,
                    success: false,
                    error: error.localizedDescription
                )
            }
        }

        // For move: clean up empty dirs
        if operation == .move {
            cleanupEmptyDirs(plan: plan, fm: fm)
        }
    }

    // MARK: - Stream Copy (256KB chunks)

    private func streamCopy(
        from source: URL,
        to destination: URL,
        progress: FileOpProgress
    ) async throws {
        guard let input = InputStream(url: source) else {
            throw FileOpError.fileNotFound(source.path)
        }
        guard let output = OutputStream(url: destination, append: false) else {
            throw FileOpError.invalidDest(destination.path)
        }

        input.open()
        output.open()
        defer {
            input.close()
            output.close()
        }

        let bufSize = 256 * 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufSize)
        defer { buffer.deallocate() }

        while true {
            if progress.isCancelled { break }

            let bytesRead = input.read(buffer, maxLength: bufSize)
            if bytesRead < 0 {
                throw FileOpError.readFailed(source.path)
            }
            if bytesRead == 0 { break }  // EOF

            let written = output.write(buffer, maxLength: bytesRead)
            if written < 0 {
                throw FileOpError.writeFailed(destination.path)
            }
            progress.add(bytes: Int64(written))
        }
    }

    // MARK: - Cleanup empty dirs after move

    private func cleanupEmptyDirs(plan: FileOpPlan, fm: FileManager) {
        // Bottom-up: sort directories by depth (deepest first)
        let dirs = plan.flatList
            .filter { $0.isDirectory }
            .sorted { $0.relativePath.components(separatedBy: "/").count > $1.relativePath.components(separatedBy: "/").count }

        for dir in dirs {
            let contents = (try? fm.contentsOfDirectory(atPath: dir.url.path)) ?? []
            if contents.isEmpty {
                try? fm.removeItem(at: dir.url)
            }
        }
    }
}
