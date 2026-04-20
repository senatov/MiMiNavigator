// FileOpsService+Delete.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 22.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Delete (trash) operations for FileOperationsService.

import Foundation

// MARK: - FileOperationsService + Delete
extension FileOpsService {

    // MARK: - Delete

    func deleteFiles(_ files: [URL]) async throws -> [URL] {
        log.info("[FileOps] deleteFiles count=\(files.count)")

        var trashedURLs: [URL] = []
        trashedURLs.reserveCapacity(files.count)

        for file in files {
            if AppLogger.isProtectedLogFile(file) {
                let diagnostic = FileOperationDiagnostics.makeProtectedDelete(source: file)
                log.error("[FileOps] delete blocked for '\(file.lastPathComponent)': \(diagnostic.details)")
                FileOperationDiagnosticPresenter.shared.show(diagnostic)
                throw CocoaError(.fileWriteNoPermission)
            }
            do {
                var resultingURL: NSURL?
                try fileManager.trashItem(at: file, resultingItemURL: &resultingURL)

                if let trashURL = resultingURL as URL? {
                    trashedURLs.append(trashURL)
                }

                log.info("[FileOps] trashed '\(file.lastPathComponent)'")
            } catch {
                let diagnostic = FileOperationDiagnostics.makeDelete(source: file, error: error)
                log.error("[FileOps] delete failed for '\(file.lastPathComponent)': \(diagnostic.details)")
                FileOperationDiagnosticPresenter.shared.show(diagnostic)
                throw error
            }
        }

        log.info("[FileOps] ✅ deleteFiles done")
        log.info("[FileOps] trashed=\(trashedURLs.count)/\(files.count)")
        return trashedURLs
    }
}
