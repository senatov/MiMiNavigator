// FindFilesEngine.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 10.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Coordinator actor — orchestrates async file search.
//   Uses /usr/bin/find via Process for accurate, streaming results.
//   Falls back to archive scanning via FindFilesArchiveSearcher.
//   Uses FileHandle.bytes for non-blocking async I/O.

import Foundation
import FileModelKit

// MARK: - Find Files Engine
/// Async search engine that runs /usr/bin/find in background and streams results via AsyncStream.
/// Supports immediate cancellation — process is killed via SIGKILL without waiting.
actor FindFilesEngine {

    private var currentTask: Task<Void, Never>?
    private var currentProcess: Process?
    private(set) var stats = FindFilesStats()

    // MARK: - Start Search

    /// Starts an async search returning results as an AsyncStream.
    func search(
        criteria: FindFilesCriteria,
        passwordCallback: ArchivePasswordCallback? = nil
    ) -> AsyncStream<FindFilesResult> {
        currentTask?.cancel()
        terminateProcess()
        stats = FindFilesStats()
        stats.isRunning = true
        stats.startTime = Date()

        log.info("[FindEngine] Starting search: pattern='\(criteria.fileNamePattern)' dir='\(criteria.searchDirectory.lastPathComponent)' archives=\(criteria.searchInArchives)")

        return AsyncStream { continuation in
            let task = Task.detached { @concurrent [weak self] in
                guard let self else {
                    continuation.finish()
                    return
                }
                await self.performSearch(criteria: criteria, continuation: continuation, passwordCallback: passwordCallback)
                continuation.finish()
                await self.markSearchComplete()
            }
            self.currentTask = task
            continuation.onTermination = { @Sendable _ in task.cancel() }
        }
    }

    // MARK: - Cancel

    func cancel() {
        currentTask?.cancel()
        currentTask = nil
        terminateProcess()
        stats.isRunning = false
        log.info("[FindEngine] Search cancelled")
    }

    // MARK: - Stats

    func getStats() -> FindFilesStats { stats }

    // MARK: - Private

    /// Force-kill the find process immediately (SIGKILL, no waiting)
    private func terminateProcess() {
        guard let proc = currentProcess else { return }
        if proc.isRunning {
            // SIGKILL for immediate termination — no zombie processes
            kill(proc.processIdentifier, SIGKILL)
        }
        currentProcess = nil
    }

    private func markSearchComplete() {
        stats.isRunning = false
        log.info("[FindEngine] Complete: \(stats.matchesFound) matches in \(stats.directoriesScanned) dirs, \(stats.filesScanned) files, \(stats.archivesScanned) archives, \(stats.formattedElapsed)")
    }

    private func performSearch(
        criteria: FindFilesCriteria,
        continuation: AsyncStream<FindFilesResult>.Continuation,
        passwordCallback: ArchivePasswordCallback?
    ) async {

        // Special case: search only inside a single archive file
        if criteria.isArchiveOnlySearch {
            log.info("[FindEngine] Archive-only search: \(criteria.searchDirectory.lastPathComponent)")
            stats.archivesScanned += 1
            let nameRegex = FindFilesNameMatcher.buildRegex(pattern: criteria.fileNamePattern, caseSensitive: criteria.caseSensitive)
            let contentPattern = criteria.isContentSearch
                ? FindFilesContentSearcher.buildPattern(text: criteria.searchText, caseSensitive: criteria.caseSensitive, useRegex: criteria.useRegex)
                : nil
            let delta = await FindFilesArchiveSearcher.searchInsideArchive(
                archiveURL: criteria.searchDirectory, criteria: criteria, nameRegex: nameRegex,
                contentPattern: contentPattern, continuation: continuation,
                passwordCallback: passwordCallback
            )
            stats.matchesFound += delta.matchesFound
            return
        }

        // Special case: single regular file content search
        if criteria.isSingleFileContentSearch {
            log.info("[FindEngine] Single-file content search: \(criteria.searchDirectory.lastPathComponent)")
            stats.filesScanned += 1
            let fileURL = criteria.searchDirectory
            let contentPattern = FindFilesContentSearcher.buildPattern(
                text: criteria.searchText, caseSensitive: criteria.caseSensitive, useRegex: criteria.useRegex)
            if let cp = contentPattern {
                let contentResults = FindFilesContentSearcher.searchFileContent(fileURL: fileURL, pattern: cp)
                for result in contentResults {
                    guard !Task.isCancelled else { return }
                    continuation.yield(result)
                    stats.matchesFound += 1
                }
            } else {
                continuation.yield(FindFilesResult(fileURL: fileURL))
                stats.matchesFound += 1
            }
            return
        }

        // Normal search — use /usr/bin/find for accurate streaming results
        await runFindCommand(criteria: criteria, continuation: continuation, passwordCallback: passwordCallback)
    }

    // MARK: - /usr/bin/find runner

    private func runFindCommand(
        criteria: FindFilesCriteria,
        continuation: AsyncStream<FindFilesResult>.Continuation,
        passwordCallback: ArchivePasswordCallback?
    ) async {
        let searchRoot = criteria.searchDirectory.path
        let pattern = criteria.fileNamePattern.isEmpty ? "*" : criteria.fileNamePattern

        // Build find arguments
        var args: [String] = [searchRoot]

        // Depth
        if !criteria.searchInSubdirectories {
            args += ["-maxdepth", "1"]
        }

        // Prune directories that cause I/O errors on virtual/offline volumes
        // (cloud storage placeholders, OneDrive, .Trash, Caches).
        // Uses -prune to skip entire subtrees — much faster than -not -path.
        let pruneNames: [String] = [
            "CloudStorage",
            "Group Containers",
            ".Trash",
            "Caches",
        ]
        // Build: \( -name X -o -name Y \) -prune -o ... -print
        var pruneArgs: [String] = ["("]
        for (i, name) in pruneNames.enumerated() {
            if i > 0 { pruneArgs.append("-o") }
            pruneArgs += ["-name", name, "-type", "d"]
        }
        pruneArgs += [")", "-prune", "-o"]

        args += pruneArgs

        // Name matching (after -prune -o)
        if criteria.useRegex {
            // Note: -E flag is inserted at args[0] before the path for BSD find
            args.insert("-E", at: 0)
            args += ["-regex", ".*\(pattern).*", "-print"]
        } else {
            let nameFlag = criteria.caseSensitive ? "-name" : "-iname"
            args += [nameFlag, pattern, "-print"]
        }

        log.info("[FindEngine] Running: find \(args.joined(separator: " "))")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/find")
        process.arguments = args

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        let contentPattern: NSRegularExpression? = criteria.isContentSearch
            ? FindFilesContentSearcher.buildPattern(text: criteria.searchText, caseSensitive: criteria.caseSensitive, useRegex: criteria.useRegex)
            : nil

        let nameRegex: NSRegularExpression? = criteria.useRegex
            ? nil
            : FindFilesNameMatcher.buildRegex(pattern: pattern, caseSensitive: criteria.caseSensitive)

        do {
            try process.run()
        } catch {
            log.error("[FindEngine] Failed to launch find: \(error.localizedDescription)")
            return
        }

        currentProcess = process

        // Async line-by-line reading using FileHandle.bytes — non-blocking, cancellation-friendly
        let handle = pipe.fileHandleForReading
        var lineBuffer = Data()
        lineBuffer.reserveCapacity(1024)

        do {
            for try await byte in handle.bytes {
                guard !Task.isCancelled else { break }

                if byte == UInt8(ascii: "\n") {
                    if let line = String(data: lineBuffer, encoding: .utf8)?
                        .trimmingCharacters(in: .whitespacesAndNewlines),
                        !line.isEmpty
                    {
                        await processFoundPath(
                            line, criteria: criteria, continuation: continuation,
                            nameRegex: nameRegex, contentPattern: contentPattern,
                            passwordCallback: passwordCallback
                        )
                    }
                    lineBuffer.removeAll(keepingCapacity: true)
                } else {
                    lineBuffer.append(byte)
                }
            }
        } catch {
            if !Task.isCancelled {
                log.warning("[FindEngine] Stream reading error: \(error.localizedDescription)")
            }
        }

        // Process remaining partial line
        if !Task.isCancelled, !lineBuffer.isEmpty,
            let line = String(data: lineBuffer, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
            !line.isEmpty
        {
            await processFoundPath(
                line, criteria: criteria, continuation: continuation,
                nameRegex: nameRegex, contentPattern: contentPattern,
                passwordCallback: passwordCallback
            )
        }

        // Cleanup process
        if process.isRunning {
            kill(process.processIdentifier, SIGKILL)
        }
        currentProcess = nil
        log.info("[FindEngine] find process exited, matched \(stats.matchesFound)")
    }

    // MARK: - Process Single Found Path

    private func processFoundPath(
        _ line: String,
        criteria: FindFilesCriteria,
        continuation: AsyncStream<FindFilesResult>.Continuation,
        nameRegex: NSRegularExpression?,
        contentPattern: NSRegularExpression?,
        passwordCallback: ArchivePasswordCallback?
    ) async {
        let fileURL = URL(fileURLWithPath: line)

        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: line, isDirectory: &isDir)
        guard exists else { return }

        stats.filesScanned += 1
        stats.currentPath = fileURL.deletingLastPathComponent().path

        if isDir.boolValue {
            stats.directoriesScanned += 1
            let result = FindFilesResult(fileURL: fileURL)
            continuation.yield(result)
            stats.matchesFound += 1
            return
        }

        // Archive: optionally search inside
        if criteria.searchInArchives && ArchiveExtensions.isArchive(fileURL.pathExtension.lowercased()) {
            stats.archivesScanned += 1
            let delta = await FindFilesArchiveSearcher.searchInsideArchive(
                archiveURL: fileURL, criteria: criteria,
                nameRegex: nameRegex, contentPattern: contentPattern,
                continuation: continuation, passwordCallback: passwordCallback
            )
            stats.matchesFound += delta.matchesFound
            return
        }

        // Content search
        if criteria.isContentSearch, let cp = contentPattern {
            let contentResults = FindFilesContentSearcher.searchFileContent(fileURL: fileURL, pattern: cp)
            for res in contentResults {
                guard !Task.isCancelled else { return }
                continuation.yield(res)
                stats.matchesFound += 1
            }
        } else {
            let result = FindFilesResult(fileURL: fileURL)
            continuation.yield(result)
            stats.matchesFound += 1
        }
    }
}
