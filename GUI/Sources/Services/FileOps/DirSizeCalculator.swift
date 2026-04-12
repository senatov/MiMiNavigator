// DirSizeCalculator.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 11.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Pre-scans items to determine total size, file count, depth, and builds flat list

import Foundation

// MARK: - Scan Result
/// Pre-scan result used for strategy selection and progress tracking
struct DirScanResult: Sendable {
    let totalBytes: Int64
    let fileCount: Int
    let maxDepth: Int
    let maxFileSize: Int64
    /// Flat list of all leaf files with relative paths and sizes
    let flatList: [FileEntry]

    struct FileEntry: Sendable {
        let url: URL
        let relativePath: String
        let size: Int64
        let isDirectory: Bool
    }
}

// MARK: - Directory Size Calculator
enum DirSizeCalculator {

    /// Scan a list of items (files and/or directories) and produce a flat manifest.
    /// Runs on a background thread — safe to call from MainActor.
    static func scan(_ items: [URL], fm: FileManager = .default) async -> DirScanResult {
        let itemsCopy = items
        return
            await Task.detached(priority: .userInitiated) {
                performScan(itemsCopy)
            }
            .value
    }

    /// Pure synchronous scan — no captured mutable state, safe for Sendable closure.
    private static func performScan(_ items: [URL]) -> DirScanResult {
        let fm = FileManager.default
        var totalBytes: Int64 = 0
        var fileCount = 0
        var maxDepth = 0
        var maxFileSize: Int64 = 0
        var flatList: [DirScanResult.FileEntry] = []

        for item in items {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: item.path, isDirectory: &isDir) else { continue }

            if isDir.boolValue {
                // .app / .framework / .bundle — treat as opaque file, don't recurse
                if isPackage(at: item, fm: fm) {
                    let size = directoryTotalSize(at: item, fm: fm)
                    totalBytes += size
                    fileCount += 1
                    maxFileSize = max(maxFileSize, size)
                    flatList.append(
                        .init(
                            url: item,
                            relativePath: item.lastPathComponent,
                            size: size,
                            isDirectory: false
                        ))
                } else {
                    scanDirectory(
                        at: item,
                        baseURL: item.deletingLastPathComponent(),
                        depth: 0,
                        fm: fm,
                        totalBytes: &totalBytes,
                        fileCount: &fileCount,
                        maxDepth: &maxDepth,
                        maxFileSize: &maxFileSize,
                        flatList: &flatList
                    )
                }
            } else {
                let size = fileSize(at: item, fm: fm)
                totalBytes += size
                fileCount += 1
                maxFileSize = max(maxFileSize, size)
                flatList.append(
                    .init(
                        url: item,
                        relativePath: item.lastPathComponent,
                        size: size,
                        isDirectory: false
                    ))
            }
        }

        log.debug("[DirScanCalc] \(fileCount) files, \(totalBytes) bytes, depth=\(maxDepth), maxFile=\(maxFileSize)")
        return DirScanResult(
            totalBytes: totalBytes,
            fileCount: fileCount,
            maxDepth: maxDepth,
            maxFileSize: maxFileSize,
            flatList: flatList
        )
    }

    // MARK: - Private

    private static func scanDirectory(
        at dirURL: URL,
        baseURL: URL,
        depth: Int,
        fm: FileManager,
        totalBytes: inout Int64,
        fileCount: inout Int,
        maxDepth: inout Int,
        maxFileSize: inout Int64,
        flatList: inout [DirScanResult.FileEntry]
    ) {
        maxDepth = max(maxDepth, depth)

        guard
            let enumerator = fm.enumerator(
                at: dirURL,
                includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
                options: []
            )
        else {
            log.warning("[DirScanCalc] can't enumerate: \(dirURL.path)")
            return
        }

        for case let fileURL as URL in enumerator {
            do {
                let vals = try fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey, .isPackageKey])
                let isDir = vals.isDirectory ?? false
                let isPkg = vals.isPackage ?? false

                if isDir && isPkg {
                    // Package (.app, .framework, .bundle) — opaque, don't recurse
                    enumerator.skipDescendants()
                    let size = directoryTotalSize(at: fileURL, fm: fm)
                    totalBytes += size
                    fileCount += 1
                    maxFileSize = max(maxFileSize, size)
                    let relPath = relativePath(of: fileURL, base: baseURL)
                    flatList.append(.init(url: fileURL, relativePath: relPath, size: size, isDirectory: false))
                } else if isDir {
                    let relPath = relativePath(of: fileURL, base: baseURL)
                    flatList.append(.init(url: fileURL, relativePath: relPath, size: 0, isDirectory: true))
                } else {
                    let size = Int64(vals.fileSize ?? 0)
                    totalBytes += size
                    fileCount += 1
                    maxFileSize = max(maxFileSize, size)

                    let relPath = relativePath(of: fileURL, base: baseURL)
                    flatList.append(.init(url: fileURL, relativePath: relPath, size: size, isDirectory: false))
                }
            } catch {
                log.warning("[DirScanCalc] skip: \(fileURL.path) — \(error.localizedDescription)")
            }
        }
    }

    private static func fileSize(at url: URL, fm: FileManager) -> Int64 {
        (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
    }


    private static func isPackage(at url: URL, fm: FileManager) -> Bool {
        (try? url.resourceValues(forKeys: [.isPackageKey]).isPackage) ?? false
    }


    /// Total size of all files inside a package/directory (for progress estimation)
    private static func directoryTotalSize(at dirURL: URL, fm: FileManager) -> Int64 {
        guard let enumerator = fm.enumerator(
            at: dirURL,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
            total += size
        }
        return total
    }

    private static func relativePath(of url: URL, base: URL) -> String {
        let fullPath = url.standardizedFileURL.path
        let basePath = base.standardizedFileURL.path
        if fullPath.hasPrefix(basePath) {
            let rel = String(fullPath.dropFirst(basePath.count))
            return rel.hasPrefix("/") ? String(rel.dropFirst()) : rel
        }
        return url.lastPathComponent
    }
}
