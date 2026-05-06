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
        let path = url.path
        let fast = fastDiskUsage(path, cancellation: cancellation)
        if fast == DirectorySizeService.unavailableSize {
            log.debug("[DirectorySizeService] Phase2 fast usage unavailable for: \(path)")
            return DirectorySizeService.unavailableSize
        }
        if fast > 0, fast < 1_000_000 {
            return fast
        }
        if fast == 0 {
            return resolvedZeroSize(url, path: path, cancellation: cancellation)
        }
        return fullRecursive(url, cancellation: cancellation)
    }

    // MARK: - Fast Disk Usage
    private static func fastDiskUsage(_ path: String, cancellation: DirectorySizeCancellationState) -> Int64 {
        guard FileManager.default.isReadableFile(atPath: path) else {
            log.debug("[DirectorySizeService] fastDiskUsage skipped unreadable: \(path)")
            return DirectorySizeService.unavailableSize
        }
        var total: Int64 = 0
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(atPath: path) else { return DirectorySizeService.unavailableSize }
        while let item = enumerator.nextObject() as? String {
            if cancellation.isCancelled {
                log.debug("[DirectorySizeService] fastDiskUsage cancelled: \(path)")
                return DirectorySizeService.unavailableSize
            }
            let fullPath = path + "/" + item
            if let allocated = statAllocatedSize(path: fullPath) {
                total += allocated
            }
        }
        return total
    }

    // MARK: - Full Recursive
    private static func fullRecursive(_ url: URL, cancellation: DirectorySizeCancellationState) -> Int64 {
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
            .fileAllocatedSizeKey,
            .totalFileAllocatedSizeKey,
        ]
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: Array(keys),
            options: [],
            errorHandler: { fileURL, error in
                if (error as NSError).code != NSFileReadNoPermissionError {
                    log.warning("[DirectorySizeService] enumerate error: \(fileURL.path) error=\(error.localizedDescription)")
                }
                return true
            }
        ) else {
            return DirectorySizeService.unavailableSize
        }
        var countedFiles = 0
        var skippedDirs = 0
        var skippedSymlinks = 0
        var resourceValueFailures = 0
        var statFallbacks = 0
        while let fileURL = enumerator.nextObject() as? URL {
            if cancellation.isCancelled {
                log.debug("[DirectorySizeService] fullRecursive cancelled: \(url.path)")
                return DirectorySizeService.unavailableSize
            }
            if let values = try? fileURL.resourceValues(forKeys: keys) {
                let result = accumulatedSize(from: values, path: fileURL.path)
                skippedSymlinks += result.skippedSymlink ? 1 : 0
                skippedDirs += result.skippedDirectory ? 1 : 0
                statFallbacks += result.usedStatFallback ? 1 : 0
                countedFiles += result.countedFile ? 1 : 0
                total += result.size
            } else {
                resourceValueFailures += 1
                if let statSize = statAllocatedSize(path: fileURL.path) {
                    statFallbacks += 1
                    countedFiles += 1
                    total += statSize
                }
            }
        }
        log.debug("[DirectorySizeService] fullRecursive done: \(url.path) total=\(total) files=\(countedFiles) skippedDirs=\(skippedDirs) skippedSymlinks=\(skippedSymlinks) rvFail=\(resourceValueFailures) statFallbacks=\(statFallbacks)")
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
        if let allocated = values.totalFileAllocatedSize {
            return SizeAccumulation(size: Int64(allocated), countedFile: true)
        }
        if let allocated = values.fileAllocatedSize {
            return SizeAccumulation(size: Int64(allocated), countedFile: true)
        }
        if let size = values.fileSize {
            return SizeAccumulation(size: Int64(size), countedFile: true)
        }
        guard let statSize = statAllocatedSize(path: path) else {
            return SizeAccumulation(countedFile: true)
        }
        return SizeAccumulation(size: statSize, usedStatFallback: true, countedFile: true)
    }

    // MARK: - Resolved Zero Size
    private static func resolvedZeroSize(_ url: URL, path: String, cancellation: DirectorySizeCancellationState) -> Int64 {
        let full = fullRecursive(url, cancellation: cancellation)
        if full == DirectorySizeService.unavailableSize {
            log.debug("[DirectorySizeService] Phase3 full recursive unavailable for: \(path)")
            return DirectorySizeService.unavailableSize
        }
        if full > 0 {
            log.debug("[DirectorySizeService] Phase3 full recursive produced non-zero result for: \(path)")
            return full
        }
        if isDirectoryEmpty(path: path) == true {
            return 0
        }
        if isDirectoryEmpty(path: path) == nil {
            log.warning("[DirectorySizeService] Directory unreadable, size unavailable: \(path)")
            return DirectorySizeService.unavailableSize
        }
        log.debug("[DirectorySizeService] Directory readable but size remained 0 after full scan: \(path)")
        return 0
    }

    // MARK: - Stat Allocated Size
    private static func statAllocatedSize(path: String) -> Int64? {
        var statbuf = stat()
        if lstat(path, &statbuf) != 0 {
            return nil
        }
        let type = statbuf.st_mode & S_IFMT
        if type == S_IFDIR || type == S_IFLNK {
            return nil
        }
        return Int64(statbuf.st_blocks) * 512
    }

    // MARK: - Directory Empty
    private static func isDirectoryEmpty(path: String) -> Bool? {
        do {
            return try FileManager.default.contentsOfDirectory(atPath: path).isEmpty
        } catch {
            log.debug("[DirectorySizeService] Cannot read directory to verify emptiness: \(path) error=\(error.localizedDescription)")
            return nil
        }
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
