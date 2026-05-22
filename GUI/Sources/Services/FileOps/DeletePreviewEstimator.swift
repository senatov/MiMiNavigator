// DeletePreviewEstimator.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 22.05.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Bounded preflight scan for recursive delete confirmations.

import Foundation

// MARK: - Delete Preview Estimate
struct DeletePreviewEstimate: Equatable, Sendable {
    let rootDirectoryCount: Int
    let fileCount: Int
    let directoryCount: Int
    let totalBytes: Int64
    let isApproximate: Bool
    let skippedCount: Int
    var hasDirectories: Bool { rootDirectoryCount > 0 }
    var sizeText: String {
        ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
    }
    var summaryText: String {
        let prefix = isApproximate ? "Approximately " : ""
        return "\(prefix)\(fileCount) file(s), \(directoryCount) folder(s), \(sizeText)"
    }
}

// MARK: - Delete Preview Estimator
enum DeletePreviewEstimator {
    private static let maxEntries = 25_000
    private static let maxDuration: TimeInterval = 2.0
    static func estimate(files: [URL]) async -> DeletePreviewEstimate {
        let urls = files
        return await Task.detached(priority: .utility) {
            performEstimate(files: urls)
        }.value
    }
    private static func performEstimate(files: [URL]) -> DeletePreviewEstimate {
        let fm = FileManager.default
        let deadline = Date().addingTimeInterval(maxDuration)
        var rootDirectoryCount = 0
        var fileCount = 0
        var directoryCount = 0
        var totalBytes: Int64 = 0
        var scannedEntries = 0
        var skippedCount = 0
        var isApproximate = false
        for url in files {
            guard Date() < deadline, scannedEntries < maxEntries else {
                isApproximate = true
                break
            }
            guard fm.fileExists(atPath: url.path) else {
                skippedCount += 1
                continue
            }
            if isDirectory(url, fm: fm) {
                rootDirectoryCount += 1
                directoryCount += 1
                scanDirectory(
                    url,
                    fm: fm,
                    deadline: deadline,
                    scannedEntries: &scannedEntries,
                    fileCount: &fileCount,
                    directoryCount: &directoryCount,
                    totalBytes: &totalBytes,
                    skippedCount: &skippedCount,
                    isApproximate: &isApproximate
                )
            } else {
                fileCount += 1
                scannedEntries += 1
                totalBytes += fileSize(url, fm: fm)
            }
        }
        return DeletePreviewEstimate(
            rootDirectoryCount: rootDirectoryCount,
            fileCount: fileCount,
            directoryCount: directoryCount,
            totalBytes: totalBytes,
            isApproximate: isApproximate,
            skippedCount: skippedCount
        )
    }
    private static func scanDirectory(
        _ root: URL,
        fm: FileManager,
        deadline: Date,
        scannedEntries: inout Int,
        fileCount: inout Int,
        directoryCount: inout Int,
        totalBytes: inout Int64,
        skippedCount: inout Int,
        isApproximate: inout Bool
    ) {
        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey, .isPackageKey],
            options: []
        ) else {
            skippedCount += 1
            isApproximate = true
            return
        }
        for case let url as URL in enumerator {
            guard Date() < deadline, scannedEntries < maxEntries else {
                isApproximate = true
                enumerator.skipDescendants()
                break
            }
            scannedEntries += 1
            if isDirectory(url, fm: fm) {
                directoryCount += 1
            } else {
                fileCount += 1
                totalBytes += fileSize(url, fm: fm)
            }
        }
    }
    private static func isDirectory(_ url: URL, fm: FileManager) -> Bool {
        var isDirectory: ObjCBool = false
        if fm.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            return isDirectory.boolValue
        }
        return (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
    }
    private static func fileSize(_ url: URL, fm: FileManager) -> Int64 {
        if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
            return Int64(size)
        }
        let attributes = try? fm.attributesOfItem(atPath: url.path)
        return (attributes?[.size] as? NSNumber)?.int64Value ?? 0
    }
}
