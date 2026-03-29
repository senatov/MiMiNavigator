// FileOpsService+Delete.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 22.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Delete (trash) operations for FileOperationsService

import Foundation

// MARK: - FileOperationsService + Delete
extension FileOperationsService {

    func deleteFiles(_ files: [URL]) async throws -> [URL] {
        log.info("[FileOps] deleteFiles: \(files.count) item(s)")
        var trashedURLs: [URL] = []
        for file in files {
            var resultingURL: NSURL?
            try fileManager.trashItem(at: file, resultingItemURL: &resultingURL)
            if let trashURL = resultingURL as URL? {
                trashedURLs.append(trashURL)
            }
            log.info("[FileOps] trashed: '\(file.lastPathComponent)'")
        }
        log.info("[FileOps] ✅ deleteFiles done: \(trashedURLs.count)/\(files.count) trashed")
        return trashedURLs
    }
}
