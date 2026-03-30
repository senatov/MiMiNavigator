// FileOpsService+SymLink.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 22.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Symbolic link creation for FileOperationsService.

import Foundation

// MARK: - FileOpsService + Symbolic Link
extension FileOpsService {

    // MARK: - Symbolic Link
    func createSymbolicLink(to source: URL, at destination: URL, linkName: String? = nil) async throws -> URL {
        let name = linkName ?? "\(source.lastPathComponent) link"
        let linkURL = destination.appendingPathComponent(name)
        let finalURL = UniqueNameGenerator.generate(for: linkURL, fileManager: fileManager)

        try fileManager.createSymbolicLink(at: finalURL, withDestinationURL: source)

        log.info("[FileOps] ✅ symlink '\(finalURL.lastPathComponent)'")
        log.info("[FileOps] target='\(source.path)'")
        return finalURL
    }
}
