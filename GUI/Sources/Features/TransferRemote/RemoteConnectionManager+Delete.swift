// RemoteConnectionManager+Delete.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Remote delete operation routed through active SFTP/FTP/SMB provider.

import Foundation

// MARK: - Remote Delete
extension RemoteConnectionManager {
    func deleteItem(remotePath: String, recursive: Bool) async throws {
        let connection = try requireActiveConnection()
        log.info("[RemoteDelete] path='\(remotePath)' recursive=\(recursive) active=\(connection.displayName)")
        try await connection.provider.deleteItem(at: remotePath, recursive: recursive)
    }
}
