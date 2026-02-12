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
    private let archiveSearcher = FindFilesArchiveSearcher()

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
            let task = Task.detached { [weak self] in
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
        let fm = FileManager.default
        let nameRegex = FindFilesNameMatcher.buildRegex(pattern: criteria.fileNamePattern, caseSensitive: criteria.caseSensitive)
        let contentPattern = criteria.isContentSearch
            ? FindFilesContentSearcher.buildPattern(text: criteria.searchText, caseSensitive: criteria.caseSensitive, useRegex: criteria.useRegex)
            : nil

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

        // Collect URLs synchronously to avoid makeIterator() in async context
        var fileURLs: [(URL, URLResourceValues?)] = []
        while let obj = enumerator.nextObject() {
            guard let fileURL = obj as? URL else { continue }
            let rv = try? fileURL.resourceValues(forKeys: Set(keys))
            let isDir = rv?.isDirectory ?? false
            if isDir {
                stats.directoriesScanned += 1
                if !criteria.searchInSubdirectories {
                    enumerator.skipDescendants()
                }
                continue
            }
            fileURLs.append((fileURL, rv))
        }

        log.debug("[FindEngine] Enumerated \(fileURLs.count) files in \(stats.directoriesScanned) dirs under \(url.lastPathComponent)")

        for (fileURL, resourceValues) in fileURLs {
            guard !Task.isCancelled else { return }

            stats.filesScanned += 1

            // Size filter
            if let minSize = criteria.fileSizeMin {
                let size = Int64(resourceValues?.fileSize ?? 0)
                if size < minSize { continue }
            }
            if let maxSize = criteria.fileSizeMax {
                let size = Int64(resourceValues?.fileSize ?? 0)
                if size > maxSize { continue }
            }

            // Date filter
            if let dateFrom = criteria.dateFrom, let modDate = resourceValues?.contentModificationDate {
                if modDate < dateFrom { continue }
            }
            if let dateTo = criteria.dateTo, let modDate = resourceValues?.contentModificationDate {
                if modDate > dateTo { continue }
            }

            let fileName = fileURL.lastPathComponent
            let nameMatches = FindFilesNameMatcher.matches(fileName: fileName, regex: nameRegex, criteria: criteria)

            // Archive handling
            let ext = fileURL.pathExtension.lowercased()
            if criteria.searchInArchives && ArchiveExtensions.isArchive(ext) {
                stats.archivesScanned += 1
                log.debug("[FindEngine] Scanning archive: \(fileURL.lastPathComponent)")

                if criteria.isContentSearch {
                    await archiveSearcher.searchInsideArchive(
                        archiveURL: fileURL, criteria: criteria, nameRegex: nameRegex,
                        contentPattern: contentPattern, continuation: continuation,
                        passwordCallback: passwordCallback, stats: &stats
                    )
                } else if nameMatches {
                    let result = FindFilesResult(fileURL: fileURL)
                    continuation.yield(result)
                    stats.matchesFound += 1
                }
                continue
            }

            // Content search: name must match AND content must contain text
            if criteria.isContentSearch {
                if nameMatches {
                    let contentResults = FindFilesContentSearcher.searchFileContent(fileURL: fileURL, pattern: contentPattern!)
                    for result in contentResults {
                        guard !Task.isCancelled else { return }
                        continuation.yield(result)
                        stats.matchesFound += 1
                    }
                }
            } else {
                // Name-only search
                if nameMatches {
                    let result = FindFilesResult(fileURL: fileURL)
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
