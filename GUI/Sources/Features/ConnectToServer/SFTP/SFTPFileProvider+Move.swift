// SFTPFileProvider+Move.swift
// MiMiNavigator
// Copyright © 2026 Senatov. All rights reserved.

import Citadel
import Foundation

// MARK: - SFTP Server-Side Move
extension SFTPFileProvider {
    @concurrent
    func moveItem(at sourcePath: String, to destinationPath: String) async throws {
        let sftp = try requireSFTPClient()
        try await sftp.rename(at: sourcePath, to: destinationPath)
        log.info("[SFTP] renamed '\(sourcePath)' → '\(destinationPath)'")
    }
}
