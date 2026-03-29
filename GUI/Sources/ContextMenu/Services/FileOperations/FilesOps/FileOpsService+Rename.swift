// FileOpsService+Rename.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 22.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Rename operations for FileOperationsService

import Foundation

// MARK: - FileOperationsService + Rename
extension FileOperationsService {

    func renameFile(_ file: URL, to newName: String) async throws -> URL {
        guard !newName.isEmpty else {
            throw FileOperationError.operationFailed("Name cannot be empty")
        }
        let parentDir = file.deletingLastPathComponent()
        let newURL = parentDir.appendingPathComponent(newName)
        log.info("[FileOps] renameFile: '\(file.path)' → '\(newURL.path)'")
        guard fileManager.fileExists(atPath: file.path) else {
            log.error("[FileOps] renameFile: source does NOT exist: '\(file.path)'")
            throw FileOperationError.operationFailed("Source file not found: \(file.lastPathComponent)")
        }
        if fileManager.fileExists(atPath: newURL.path) && newURL.path != file.path {
            throw FileOperationError.fileAlreadyExists(newName)
        }
        try fileManager.moveItem(at: file, to: newURL)
        let verifyExists = fileManager.fileExists(atPath: newURL.path)
        log.info("[FileOps] ✅ renamed: '\(file.lastPathComponent)' → '\(newName)' verify=\(verifyExists)")
        return newURL
    }
}
