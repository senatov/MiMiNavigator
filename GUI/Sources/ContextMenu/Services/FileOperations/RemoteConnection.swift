//
//  RemoteConnection.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 28.03.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import Foundation

// MARK: - Connection state for a single remote session
struct RemoteConnection: Identifiable {
    let id: UUID
    let server: RemoteServer
    let provider: any RemoteFileProvider
    let connectedAt: Date
    var currentPath: String

    // MARK: - Display
    var displayName: String {
        server.displayName
    }

    var protocolType: RemoteProtocol {
        server.remoteProtocol
    }

    // MARK: - Identity
    var normalizedHost: String {
        Self.normalizeHost(server.host)
    }

    var normalizedRemotePath: String {
        Self.normalizeRemotePath(server.remotePath)
    }

    var normalizedCurrentPath: String {
        Self.normalizeRemotePath(currentPath)
    }

    func matches(server other: RemoteServer) -> Bool {
        normalizedHost == Self.normalizeHost(other.host)
            && server.port == other.port
            && server.remoteProtocol == other.remoteProtocol
            && server.user == other.user
            && normalizedRemotePath == Self.normalizeRemotePath(other.remotePath)
    }

    // MARK: - Helpers
    private static func normalizeHost(_ host: String) -> String {
        host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func normalizeRemotePath(_ path: String) -> String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "/" : trimmed
    }
}
