// FileOpsService+Rename.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 22.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Rename operations for FileOperationsService.

import Foundation

// MARK: - FileOperationsService + Rename
extension FileOpsService {

    // MARK: - Rename
    func renameFile(_ file: URL, to newName: String) async throws -> URL {
        guard !newName.isEmpty else {
            throw FileOpsError.operationFailed("Name cannot be empty")
        }

        let parentDir = file.deletingLastPathComponent()
        let newURL = parentDir.appendingPathComponent(newName)

        log.info("[FileOps] renameFile old='\(file.path)'")
        log.info("[FileOps] renameFile new='\(newURL.path)'")

        guard fileManager.fileExists(atPath: file.path) else {
            log.error("[FileOps] renameFile source missing='\(file.path)'")
            throw FileOpsError.operationFailed("Source file not found: \(file.lastPathComponent)")
        }

        if fileManager.fileExists(atPath: newURL.path), newURL.path != file.path {
            throw FileOpsError.fileAlreadyExists(newName)
        }

        try fileManager.moveItem(at: file, to: newURL)

        let verifyExists = fileManager.fileExists(atPath: newURL.path)
        log.info("[FileOps] ✅ renamed '\(file.lastPathComponent)'")
        log.info("[FileOps] verify=\(verifyExists) newName='\(newName)'")
        return newURL
    }
}
