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

    static func detect(scan: DirScanResult) -> FileOpStrategy {
        let mb100: Int64 = 100 * 1024 * 1024
        let gb1: Int64 = 1024 * 1024 * 1024

        // FewLarge: huge files or huge total
        if scan.maxFileSize > mb100 || scan.totalBytes > gb1 {
            log.info("[FileOpStrategy] → fewLarge (maxFile=\(scan.maxFileSize), total=\(scan.totalBytes))")
            return .fewLarge
        }

        // ManySmall: lots of files or deep tree
        if scan.fileCount > 50 || scan.maxDepth > 3 {
            log.info("[FileOpStrategy] → manySmall (files=\(scan.fileCount), depth=\(scan.maxDepth))")
            return .manySmall
        }

        if scan.flatList.contains(where: \.isDirectory) {
            log.info("[FileOpStrategy] → manySmall (directory manifest)")
            return .manySmall
        }

        // Simple: small quick job
        let mb50: Int64 = 50 * 1024 * 1024
        if scan.fileCount <= 10 && scan.totalBytes < mb50 {
            log.info("[FileOpStrategy] → simple (files=\(scan.fileCount), total=\(scan.totalBytes))")
            return .simple
        }

        // Default to manySmall for middle ground
        log.info("[FileOpStrategy] → manySmall (default)")
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
