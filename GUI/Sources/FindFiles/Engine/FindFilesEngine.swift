// FindFilesEngine.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 10.02.2026.
// Refactored: 12.02.2026 — split into Engine + NameMatcher + ContentSearcher + ArchiveSearcher + Models
// Copyright © 2026 Senatov. All rights reserved.
// Description: Coordinator actor — orchestrates async file search using modular sub-components

import Foundation

// MARK: - Find Files Engine
/// Async search engine that runs in background and streams results via AsyncStream.
/// Delegates work to: FindFilesNameMatcher, FindFilesContentSearcher, FindFilesArchiveSearcher.
/// Supports cancellation via Swift concurrency Task cancellation.
actor FindFilesEngine {

    private var currentTask: Task<Void, Never>?
    private(set) var stats = FindFilesStats()

    // MARK: - Start Search

    /// Starts an async search returning results as an AsyncStream.
    func search(
        criteria: FindFilesCriteria,
        passwordCallback: ArchivePasswordCallback? = nil
    ) -> AsyncStream<FindFilesResult> {
        currentTask?.cancel()
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
        stats.isRunning = false
        log.info("[FindEngine] Search cancelled")
    }

    // MARK: - Stats

    func getStats() -> FindFilesStats { stats }

    // MARK: - Private

    private func markSearchComplete() {
        stats.isRunning = false
        log.info("[FindEngine] Complete: \(stats.matchesFound) matches in \(stats.directoriesScanned) dirs, \(stats.filesScanned) files, \(stats.archivesScanned) archives, \(stats.formattedElapsed)")
    }

    private func performSearch(
        criteria: FindFilesCriteria,
        continuation: AsyncStream<FindFilesResult>.Continuation,
        passwordCallback: ArchivePasswordCallback?
    ) async {
        let nameRegex = FindFilesNameMatcher.buildRegex(pattern: criteria.fileNamePattern, caseSensitive: criteria.caseSensitive)
        let contentPattern = criteria.isContentSearch
            ? FindFilesContentSearcher.buildPattern(text: criteria.searchText, caseSensitive: criteria.caseSensitive, useRegex: criteria.useRegex)
            : nil

        // Special case: search only inside a single archive file
        if criteria.isArchiveOnlySearch {
            log.info("[FindEngine] Archive-only search: \(criteria.searchDirectory.lastPathComponent)")
            stats.archivesScanned += 1

            let delta = await FindFilesArchiveSearcher.searchInsideArchive(
                archiveURL: criteria.searchDirectory, criteria: criteria, nameRegex: nameRegex,
                contentPattern: contentPattern, continuation: continuation,
                passwordCallback: passwordCallback
            )
            stats.matchesFound += delta.matchesFound
            return
        }

        // Special case: single regular file — search its text content
        if criteria.isSingleFileContentSearch {
            log.info("[FindEngine] Single-file content search: \(criteria.searchDirectory.lastPathComponent)")
            stats.filesScanned += 1
            let fileURL = criteria.searchDirectory
            if let cp = contentPattern {
                let contentResults = FindFilesContentSearcher.searchFileContent(fileURL: fileURL, pattern: cp)
                for result in contentResults {
                    guard !Task.isCancelled else { return }
                    continuation.yield(result)
                    stats.matchesFound += 1
                }
            } else {
                // No text filter — just yield the file itself
                continuation.yield(FindFilesResult(fileURL: fileURL))
                stats.matchesFound += 1
            }
            return
        }

        // Normal directory search
        let fm = FileManager.default
        await scanDirectory(
            url: criteria.searchDirectory, criteria: criteria,
            nameRegex: nameRegex, contentPattern: contentPattern,
            continuation: continuation, passwordCallback: passwordCallback, fm: fm
        )
    }

    private func scanDirectory(
        url: URL,
        criteria: FindFilesCriteria,
        nameRegex: NSRegularExpression?,
        contentPattern: NSRegularExpression?,
        continuation: AsyncStream<FindFilesResult>.Continuation,
        passwordCallback: ArchivePasswordCallback?,
        fm: FileManager
    ) async {
        guard !Task.isCancelled else { return }

        let keys: [URLResourceKey] = [.isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey, .contentModificationDateKey]
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: keys,
            options: [.skipsPackageDescendants]
        ) else {
            log.warning("[FindEngine] Cannot enumerate: \(url.path)")
            return
        }

        // Collect file metadata into Sendable struct to avoid URLResourceValues crossing await
        var entries: [ScannedFileEntry] = []
        while let obj = enumerator.nextObject() {
            guard let fileURL = obj as? URL else { continue }
            let rv = try? fileURL.resourceValues(forKeys: Set(keys))
            let isDir = rv?.isDirectory ?? false
            if isDir {
                stats.directoriesScanned += 1
                stats.currentPath = fileURL.path
                if !criteria.searchInSubdirectories {
                    enumerator.skipDescendants()
                }
                continue
            }
            entries.append(ScannedFileEntry(
                url: fileURL,
                fileSize: Int64(rv?.fileSize ?? 0),
                modificationDate: rv?.contentModificationDate
            ))
        }

        log.debug("[FindEngine] Enumerated \(entries.count) files in \(stats.directoriesScanned) dirs under \(url.lastPathComponent)")

        // Separate archives from regular files for parallel processing
        var regularEntries: [ScannedFileEntry] = []
        var archiveEntries: [ScannedFileEntry] = []

        for entry in entries {
            // Size filter
            if let minSize = criteria.fileSizeMin, entry.fileSize < minSize { continue }
            if let maxSize = criteria.fileSizeMax, entry.fileSize > maxSize { continue }
            // Date filter
            if let dateFrom = criteria.dateFrom, let modDate = entry.modificationDate, modDate < dateFrom { continue }
            if let dateTo = criteria.dateTo, let modDate = entry.modificationDate, modDate > dateTo { continue }

            let ext = entry.url.pathExtension.lowercased()
            if criteria.searchInArchives && ArchiveExtensions.isArchive(ext) {
                archiveEntries.append(entry)
            } else {
                regularEntries.append(entry)
            }
        }

        // Process archives in parallel (up to 4 concurrent archive scans)
        if !archiveEntries.isEmpty {
            log.debug("[FindEngine] Scanning \(archiveEntries.count) archives in parallel")

            await withTaskGroup(of: ArchiveSearchDelta.self) { group in
                let maxConcurrent = 8  // M3 has plenty of cores for I/O-bound archive scanning
                var launched = 0

                for archiveEntry in archiveEntries {
                    guard !Task.isCancelled else { break }

                    // Throttle: wait for a slot if we've launched max concurrent tasks
                    if launched >= maxConcurrent {
                        if let delta = await group.next() {
                            stats.matchesFound += delta.matchesFound
                        }
                    }

                    group.addTask { @concurrent in
                        await FindFilesArchiveSearcher.searchInsideArchive(
                            archiveURL: archiveEntry.url, criteria: criteria,
                            nameRegex: nameRegex, contentPattern: contentPattern,
                            continuation: continuation, passwordCallback: passwordCallback)
                    }
                    launched += 1
                    stats.archivesScanned += 1
                }

                // Collect remaining results
                for await delta in group {
                    stats.matchesFound += delta.matchesFound
                }
            }
        }

        // Process regular files sequentially
        for entry in regularEntries {
            guard !Task.isCancelled else { return }

            stats.filesScanned += 1

            let fileName = entry.url.lastPathComponent
            let nameMatches = FindFilesNameMatcher.matches(fileName: fileName, regex: nameRegex, criteria: criteria)

            // Content search: name must match AND content must contain text
            if criteria.isContentSearch {
                if nameMatches {
                    let contentResults = FindFilesContentSearcher.searchFileContent(fileURL: entry.url, pattern: contentPattern!)
                    for result in contentResults {
                        guard !Task.isCancelled else { return }
                        continuation.yield(result)
                        stats.matchesFound += 1
                    }
                }
            } else {
                // Name-only search
                if nameMatches {
                    let result = FindFilesResult(fileURL: entry.url)
                    continuation.yield(result)
                    stats.matchesFound += 1
                }
            }

            // Yield control periodically
            if stats.filesScanned % 200 == 0 {
                await Task.yield()
            }
        }
    }
}
