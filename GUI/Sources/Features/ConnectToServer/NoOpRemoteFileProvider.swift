// NoOpRemoteFileProvider.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Stub provider for protocols that use native OS mount (SMB/AFP).

import FileModelKit
import Foundation


// MARK: - NoOpRemoteFileProvider

final class NoOpRemoteFileProvider: RemoteFileProvider, @unchecked Sendable {
    private(set) var isConnected = false
    private(set) var mountPath = ""
    private let reason: String

    init(reason: String) { self.reason = reason }

    @concurrent func connect(host: String, port: Int, user: String, password: String, remotePath: String) async throws {
        throw RemoteProviderError.notImplemented
    }

    @concurrent func listDirectory(_ path: String) async throws -> [RemoteFileItem] {
        throw RemoteProviderError.notImplemented
    }

    @concurrent func downloadFile(remotePath: String) async throws -> URL {
        throw RemoteProviderError.notImplemented
    }

    @concurrent func downloadToLocal(remotePath: String, localPath: String, recursive: Bool) async throws {
        throw RemoteProviderError.notImplemented
    }

    @concurrent func disconnect() async {}
}
