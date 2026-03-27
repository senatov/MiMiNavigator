//
//  RemoteConnectionManager.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 28.03.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import AppKit
import FileModelKit
import Foundation
import UniformTypeIdentifiers

// MARK: - RemoteConnectionManager
@MainActor
@Observable
final class RemoteConnectionManager {

    static let shared = RemoteConnectionManager()

    private(set) var connections: [RemoteConnection] = []
    private(set) var activeConnectionID: UUID?

    var isConnected: Bool { !connections.isEmpty }

    var activeConnection: RemoteConnection? {
        guard let id = activeConnectionID else { return connections.first }
        return connections.first { $0.id == id }
    }

    private init() {}

    // MARK: - Auto-connect
    func connectOnStartIfNeeded() async {
        let servers = RemoteServerStore.shared.servers.filter { $0.connectOnStart }
        guard !servers.isEmpty else { return }

        log.info("[RemoteManager] auto-connecting \(servers.count) server(s)")

        for server in servers {
            let password = RemoteServerKeychain.loadPassword(for: server)
            guard !password.isEmpty else {
                log.warning("[RemoteManager] skip auto-connect '\(server.displayName)' — no saved password")
                continue
            }
            await connect(to: server, password: password)
        }
    }

    // MARK: - Connect
    func connect(to server: RemoteServer, password: String) async {
        log.info("[RemoteManager] connecting to \(server.displayName) via \(server.remoteProtocol.rawValue)")

        if let existing = connection(for: server) {
            log.warning("[RemoteManager] already connected to \(server.displayName), reusing existing connection")
            activeConnectionID = existing.id
            return
        }

        let provider = createProvider(for: server.remoteProtocol)

        do {
            try await provider.connect(
                host: server.host,
                port: server.port,
                user: server.user,
                password: password,
                remotePath: server.remotePath
            )

            let startPath = server.remotePath.isEmpty ? "/" : server.remotePath
            let connection = RemoteConnection(
                id: UUID(),
                server: server,
                provider: provider,
                connectedAt: Date(),
                currentPath: startPath
            )

            connections.append(connection)
            activeConnectionID = connection.id
            updateServerResult(server, result: .success, errorDetail: nil)

            log.info("\(#function) connected: \(connection.displayName) id=\(connection.id) total=\(connections.count)")
        } catch {
            let nsError = error as NSError
            let result = classifyError(error)
            updateServerResult(server, result: result, errorDetail: error.localizedDescription)
            log.error(
                """
                \(#function) FAILED host=\(server.host):\(server.port) proto=\(server.remoteProtocol.rawValue)
                domain=\(nsError.domain) code=\(nsError.code) classified=\(result.rawValue)
                desc=\(nsError.localizedDescription)
                """
            )
        }
    }

    // MARK: - Disconnect
    func disconnect(id: UUID) async {
        guard let idx = connections.firstIndex(where: { $0.id == id }) else { return }

        let connection = connections[idx]
        await connection.provider.disconnect()
        connections.remove(at: idx)

        if activeConnectionID == id {
            activeConnectionID = connections.first?.id
        }

        log.info("[RemoteManager] disconnected: \(connection.displayName) id=\(connection.id) remaining=\(connections.count)")
    }

    func disconnectAll() async {
        for connection in connections {
            await connection.provider.disconnect()
        }
        connections.removeAll()
        activeConnectionID = nil
        log.info("[RemoteManager] all connections closed")
    }

    // MARK: - Active connection
    func setActive(id: UUID) {
        guard connections.contains(where: { $0.id == id }) else { return }
        activeConnectionID = id
    }

    func connection(for server: RemoteServer) -> RemoteConnection? {
        connections.first {
            $0.server.host == server.host
                && $0.server.port == server.port
                && $0.server.remoteProtocol == server.remoteProtocol
        }
    }

    // MARK: - Remote operations
    func listDirectory(_ path: String) async throws -> [RemoteFileItem] {
        log.debug("[RemoteManager] listDirectory path=\(path) active=\(activeConnection?.displayName ?? "none")")
        guard let connection = activeConnection else {
            throw RemoteProviderError.notConnected
        }

        let items = try await connection.provider.listDirectory(path)
        if let idx = connections.firstIndex(where: { $0.id == connection.id }) {
            connections[idx].currentPath = path
        }
        return items
    }

    func downloadFile(remotePath: String) async throws -> URL {
        guard let connection = activeConnection else {
            throw RemoteProviderError.notConnected
        }
        log.info("[RemoteManager] downloadFile '\(remotePath)'")
        return try await connection.provider.downloadFile(remotePath: remotePath)
    }

    func navigateUp() async throws -> [RemoteFileItem] {
        guard let connection = activeConnection else {
            throw RemoteProviderError.notConnected
        }

        let parent = (connection.currentPath as NSString).deletingLastPathComponent
        let normalizedParent = parent.isEmpty ? "/" : parent
        return try await listDirectory(normalizedParent)
    }

    // MARK: - Helpers
    private func createProvider(for proto: RemoteProtocol) -> any RemoteFileProvider {
        log.debug("\(#function)(\(proto))")
        switch proto {
            case .sftp:
                return SFTPFileProvider()
            case .ftp:
                return FTPFileProvider()
            default:
                log.warning("\(#function) unsupported remote protocol=\(proto.rawValue), falling back to FTP provider")
                return FTPFileProvider()
        }
    }

    private func updateServerResult(_ server: RemoteServer, result: ConnectionResult, errorDetail: String?) {
        log.debug("\(#function) \(server.displayName) → \(result.rawValue)")
        var updated = server
        updated.lastConnected = Date()
        updated.lastResult = result
        updated.lastErrorDetail = errorDetail
        RemoteServerStore.shared.update(updated)
    }

    private func classifyError(_ error: Error) -> ConnectionResult {
        log.debug("\(#function)(\(error))")
        let raw = String(describing: error).lowercased()
        let message = error.localizedDescription.lowercased()

        if let providerError = error as? RemoteProviderError {
            switch providerError {
                case .authFailed:
                    return .authFailed
                case .notConnected,
                    .notImplemented,
                    .invalidURL,
                    .listingFailed,
                    .downloadFailed:
                    return .error
                @unknown default:
                    log.warning("\(#function): unhandled RemoteProviderError=\(providerError)")
                    return .error
            }
        }

        if message.contains("timeout") || message.contains("timed out") {
            return .timeout
        }

        if message.contains("refused") || message.contains("connection refused") {
            return .refused
        }

        if message.contains("auth")
            || message.contains("password")
            || message.contains("denied")
            || raw.contains("allauthenticationoptionsfailed")
        {
            return .authFailed
        }

        return .error
    }
}
