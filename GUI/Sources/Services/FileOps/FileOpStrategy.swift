// FileOpStrategy.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 11.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Selects optimal file operation strategy based on pre-scan results

import Foundation

// MARK: - Operation Type
enum FileOpType: String, Sendable {
    case copy = "Copying"
    case move = "Moving"

    var title: String {
        switch self {
        case .copy: return L10n.BatchOperation.copying
        case .move: return L10n.BatchOperation.moving
        }
    }

    var pastTense: String {
        switch self {
        case .copy: return L10n.BatchOperation.copied
        case .move: return L10n.BatchOperation.moved
        }
    }
}

// MARK: - Strategy
/// Three strategies depending on workload shape
enum FileOpStrategy: String, Sendable {
    /// < 10 files AND < 50 MB total — fast sequential, no progress panel
    case simple
    /// > 50 files OR > 3 levels deep — parallel TaskGroup (up to 5 concurrent)
    case manySmall
    /// Any file > 100 MB OR total > 1 GB — stream-copy with byte-level progress
    case fewLarge

    /// large file threshold — files above this use streamCopy
    static let largeFileThreshold: Int64 = 100 * 1024 * 1024



    static func detect(scan: DirScanResult) -> FileOpStrategy {
        let mb100 = largeFileThreshold

        // Simple: small quick job (< 10 files AND < 50 MB)
        let mb50: Int64 = 50 * 1024 * 1024
        if scan.fileCount <= 10 && scan.totalBytes < mb50 && !scan.flatList.contains(where: \.isDirectory) {
            log.info("[FileOpStrategy] → simple (files=\(scan.fileCount), total=\(scan.totalBytes))")
            return .simple
        }

        // FewLarge: ONLY when ALL files are big or very few files total
        let largeFiles = scan.flatList.filter { !$0.isDirectory && $0.size > mb100 }
        let smallFiles = scan.fileCount - largeFiles.count
        if !largeFiles.isEmpty && smallFiles <= 5 {
            log.info("[FileOpStrategy] → fewLarge (\(largeFiles.count) large, \(smallFiles) small)")
            return .fewLarge
        }

        // ManySmall: everything else — parallel with TaskGroup
        // works for mixed batches too (large files handled via streamCopy inside)
        log.info("[FileOpStrategy] → manySmall (files=\(scan.fileCount), depth=\(scan.maxDepth), large=\(largeFiles.count))")
        return .manySmall
    }
}

// MARK: - Execution Plan
/// Pre-computed plan for a file operation
struct FileOpPlan: Sendable {
    let items: [URL]
    let destination: URL
    let strategy: FileOpStrategy
    let totalBytes: Int64
    let fileCount: Int
    let flatList: [DirScanResult.FileEntry]
}
