// DirectorySizeNativeCalculator.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 06.05.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Native directory size calculations for DirectorySizeService.

import Darwin
import Foundation

// MARK: - Directory Size Native Calculator
enum DirectorySizeNativeCalculator {
    private static let maximumEntryCount = 200_000
    private static let maximumDuration: TimeInterval = 8
    private static let fallbackMaximumEntryCount = 500_000
    private static let fallbackMaximumDuration: TimeInterval = 20
    private static let autoreleaseBatchSize = 512

    // MARK: - Shallow Size
    static func shallowSize(_ url: URL) -> Int64 {
        var total: Int64 = 0
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .fileSizeKey]
        guard
            let children = try? FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: Array(keys),
                options: []
            )
        else {
            return DirectorySizeService.unavailableSize
        }
        for child in children {
            guard let values = try? child.resourceValues(forKeys: keys) else { continue }
            guard values.isRegularFile == true else { continue }
            total += Int64(values.fileSize ?? 0)
        }
        return total
    }

    // MARK: - Directory Size
    static func directorySize(_ url: URL, cancellation: DirectorySizeCancellationState) -> Int64 {
        guard FileManager.default.isReadableFile(atPath: url.path) else {
            log.debug("[DirectorySizeService] skipping unreadable directory: \(url.path)")
            return DirectorySizeService.unavailableSize
        }
        return fullRecursive(
            url,
            cancellation: cancellation,
            options: [],
            maximumEntryCount: maximumEntryCount,
            maximumDuration: maximumDuration
        )
    }

    // MARK: - Fallback Directory Size
    static func fallbackDirectorySize(_ url: URL, cancellation: DirectorySizeCancellationState) -> Int64 {
        fullRecursive(
            url,
            cancellation: cancellation,
            options: [],
            maximumEntryCount: fallbackMaximumEntryCount,
            maximumDuration: fallbackMaximumDuration
        )
    }

    // MARK: - Full Recursive
    private static func fullRecursive(
        _ url: URL,
        cancellation: DirectorySizeCancellationState,
        options: FileManager.DirectoryEnumerationOptions,
        maximumEntryCount: Int,
        maximumDuration: TimeInterval
    ) -> Int64 {
        guard FileManager.default.isReadableFile(atPath: url.path) else {
            log.debug("[DirectorySizeService] fullRecursive skipped unreadable: \(url.path)")
            return DirectorySizeService.unavailableSize
        }
        var total: Int64 = 0
        let keys: Set<URLResourceKey> = [
            .isRegularFileKey,
            .isDirectoryKey,
            .isSymbolicLinkKey,
            .fileSizeKey,
        ]
        guard
            let enumerator = FileManager.default.enumerator(
                at: url,
                includingPropertiesForKeys: Array(keys),
                options: options,
                errorHandler: { fileURL, error in
                    if (error as NSError).code != NSFileReadNoPermissionError {
                        log.warning("[DirectorySizeService] enumerate error: \(fileURL.path) error=\(error.localizedDescription)")
                    }
                    return true
                }
            )
        else {
            return DirectorySizeService.unavailableSize
        }
        var countedFiles = 0
        var skippedDirs = 0
        var skippedSymlinks = 0
        var resourceValueFailures = 0
        var statFallbacks = 0
        var visitedEntries = 0
        var isFinished = false
        let startedAt = Date()
        while !isFinished {
            let batch = autoreleasepool {
                var accumulation = SizeScanBatch()
                for _ in 0..<autoreleaseBatchSize {
                    guard let fileURL = enumerator.nextObject() as? URL else {
                        accumulation.reachedEnd = true
                        break
                    }
                    accumulation.visitedEntries += 1
                    if let values = try? fileURL.resourceValues(forKeys: keys) {
                        accumulation.append(accumulatedSize(from: values, path: fileURL.path))
                    } else {
                        accumulation.resourceValueFailures += 1
                        if let statSize = statLogicalSize(path: fileURL.path) {
                            accumulation.statFallbacks += 1
                            accumulation.countedFiles += 1
                            accumulation.total += statSize
                        }
                    }
                }
                return accumulation
            }
            total += batch.total
            countedFiles += batch.countedFiles
            skippedDirs += batch.skippedDirs
            skippedSymlinks += batch.skippedSymlinks
            resourceValueFailures += batch.resourceValueFailures
            statFallbacks += batch.statFallbacks
            visitedEntries += batch.visitedEntries
            isFinished = batch.reachedEnd

            if cancellation.isCancelled {
                log.debug("[DirectorySizeService] fullRecursive cancelled: \(url.path)")
                return DirectorySizeService.unavailableSize
            }
            if visitedEntries >= maximumEntryCount || Date().timeIntervalSince(startedAt) >= maximumDuration {
                let elapsed = String(format: "%.1f", Date().timeIntervalSince(startedAt))
                log.warning(
                    "[DirectorySizeService] scan budget exceeded path='\(url.path)' "
                        + "entries=\(visitedEntries) elapsed=\(elapsed)s"
                )
                return DirectorySizeService.unavailableSize
            }
        }
        log.debug(
            "[DirectorySizeService] fullRecursive done: \(url.path) total=\(total) files=\(countedFiles) skippedDirs=\(skippedDirs) skippedSymlinks=\(skippedSymlinks) rvFail=\(resourceValueFailures) statFallbacks=\(statFallbacks)"
        )
        return total
    }

    // MARK: - Accumulated Size
    private static func accumulatedSize(from values: URLResourceValues, path: String) -> SizeAccumulation {
        if values.isSymbolicLink == true {
            return SizeAccumulation(skippedSymlink: true)
        }
        if values.isDirectory == true {
            return SizeAccumulation(skippedDirectory: true)
        }
        guard values.isRegularFile == true else {
            return SizeAccumulation()
        }
        if let size = values.fileSize {
            return SizeAccumulation(size: Int64(size), countedFile: true)
        }
        guard let statSize = statLogicalSize(path: path) else {
            return SizeAccumulation(countedFile: true)
        }
        return SizeAccumulation(size: statSize, usedStatFallback: true, countedFile: true)
    }

    // MARK: - Stat Allocated Size
    private static func statLogicalSize(path: String) -> Int64? {
        var statbuf = stat()
        if lstat(path, &statbuf) != 0 {
            return nil
        }
        let type = statbuf.st_mode & S_IFMT
        if type == S_IFDIR || type == S_IFLNK {
            return nil
        }
        return Int64(statbuf.st_size)
    }

}

// MARK: - Size Accumulation
private struct SizeAccumulation {
    var size: Int64 = 0
    var skippedSymlink = false
    var skippedDirectory = false
    var usedStatFallback = false
    var countedFile = false
}

private struct SizeScanBatch {
    var total: Int64 = 0
    var countedFiles = 0
    var skippedDirs = 0
    var skippedSymlinks = 0
    var resourceValueFailures = 0
    var statFallbacks = 0
    var visitedEntries = 0
    var reachedEnd = false

    mutating func append(_ result: SizeAccumulation) {
        total += result.size
        countedFiles += result.countedFile ? 1 : 0
        skippedDirs += result.skippedDirectory ? 1 : 0
        skippedSymlinks += result.skippedSymlink ? 1 : 0
        statFallbacks += result.usedStatFallback ? 1 : 0
    }
}
