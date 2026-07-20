// BackupArchiveService.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Creates timestamped ZIP backups beside selected items.

import FileModelKit
import Foundation

// MARK: - Backup Assessment
struct BackupAssessment: Sendable {
    let totalBytes: Int64
    let fileCount: Int
    let isApproximate: Bool
    var requiresConfirmation: Bool {
        isApproximate || totalBytes >= BackupArchiveService.largeSizeThreshold || fileCount >= BackupArchiveService.largeFileCountThreshold
    }
    var summary: String {
        let size = ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
        let prefix = isApproximate ? "At least " : ""
        return "\(prefix)\(size) in \(fileCount) file(s)"
    }
}

// MARK: - Backup Archive Service
enum BackupArchiveService {
    static let largeSizeThreshold: Int64 = 100 * 1024 * 1024
    static let largeFileCountThreshold = 1_000
    // MARK: - Assess
    static func assess(files: [CustomFile]) async -> BackupAssessment {
        let estimate = await DeletePreviewEstimator.estimate(files: files.map(\.urlValue))
        return BackupAssessment(totalBytes: estimate.totalBytes, fileCount: estimate.fileCount, isApproximate: estimate.isApproximate)
    }
    // MARK: - Archive Name
    static func archiveURL(for files: [CustomFile], now: Date = Date()) -> URL? {
        guard let first = files.first else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        let directory = first.urlValue.deletingLastPathComponent()
        let baseName = "\(first.nameStr).\(formatter.string(from: now))"
        var candidate = directory.appendingPathComponent("\(baseName).zip")
        var counter = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = directory.appendingPathComponent("\(baseName)-\(counter).zip")
            counter += 1
        }
        return candidate
    }
}
