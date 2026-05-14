// FileOpsEngine+Delete.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 14.05.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Delete implementation — moves items to Trash.

import Foundation

// MARK: - Delete Implementation

extension FileOpsEngine {

    func performDelete(items: [URL]) async throws -> FileOpProgress {
        let totalSize = calculateTotalSize(items: items)
        let progress = FileOpProgress(totalFiles: items.count, totalBytes: totalSize, type: .copy, destination: nil)
        showPanel(progress: progress, itemCount: items.count, operation: "delete")
        defer { progress.complete() }
        for url in items {
            guard !progress.isCancelled else { break }
            trashItem(url: url, progress: progress)
        }
        return progress
    }



    func trashItem(url: URL, progress: FileOpProgress) {
        progress.setCurrentFile(url.lastPathComponent)
        if AppLogger.isProtectedLogFile(url) {
            recordFailure(
                FileOperationDiagnostics.makeProtectedDelete(source: url),
                progress: progress
            )
            return
        }
        do {
            try fm.trashItem(at: url, resultingItemURL: nil)
            progress.fileCompleted(name: url.lastPathComponent, success: true)
            progress.add(bytes: fileSize(url: url))
        } catch {
            recordFailure(
                FileOperationDiagnostics.makeDelete(source: url, error: error),
                progress: progress
            )
        }
    }
}
