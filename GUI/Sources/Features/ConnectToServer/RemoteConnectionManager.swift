// RemoteConnectionManager.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Singleton managing active remote connections (SFTP / FTP).
//   Owns RemoteFileProvider instances, handles connect/disconnect lifecycle,
//   publishes connection state for UI (status bar, panel integration).
//   Thread-safe: @MainActor for UI state, provider calls via Task.

import Foundation

// MARK: - Connection state for a single remote session
struct RemoteConnection: Identifiable {
    let id: UUID
    let server: RemoteServer
    let provider: any RemoteFileProvider
    let connectedAt: Date
    var currentPath: String

    var displayName: String { server.displayName }
    var protocolType: RemoteProtocol { server.remoteProtocol }
}

// MARK: - RemoteConnectionManager
@MainActor
@Observable
final class RemoteConnectionManager {

    static let shared = RemoteConnectionManager()

    // All active connections
    private(set) var connections: [RemoteConnection] = []

    // Currently active connection (for panel display)
    private(set) var activeConnectionID: UUID?

    var isConnected: Bool { !connections.isEmpty }

    var activeConnection: RemoteConnection? {
        guard let id = activeConnectionID else { return connections.first }
        return connections.first { $0.id == id }
    }

    private init() {}

    // MARK: - Auto-connect servers marked with connectOnStart
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
        let provider = createProvider(for: server.remoteProtocol)
        do {
            try await provider.connect(
                host: server.host,
                port: server.port,
                user: server.user,
                password: password,
                remotePath: server.remotePath
            )
            let connection = RemoteConnection(
                id: UUID(),
                server: server,
                provider: provider,
                connectedAt: Date(),
                currentPath: server.remotePath.isEmpty ? "/" : server.remotePath
            )
            connections.append(connection)
            activeConnectionID = connection.id
            updateServerResult(server, result: .success)
            log.info("[RemoteManager] connected: \(connection.displayName) (\(connections.count) total)")
        } catch {
            let result = classifyError(error)
            updateServerResult(server, result: result)
            log.error("[RemoteManager] connect failed: \(error.localizedDescription) → \(result.rawValue)")
        }
    }

    // MARK: - Disconnect
    func disconnect(id: UUID) async {
        guard let idx = connections.firstIndex(where: { $0.id == id }) else { return }
        let conn = connections[idx]
        await conn.provider.disconnect()
        connections.remove(at: idx)
        if activeConnectionID == id {
            activeConnectionID = connections.first?.id
        }
        log.info("[RemoteManager] disconnected: \(conn.displayName) (\(connections.count) remaining)")
    }

    func disconnectAll() async {
        for conn in connections {
            await conn.provider.disconnect()
        }
        connections.removeAll()
        activeConnectionID = nil
        log.info("[RemoteManager] all connections closed")
    }

    // MARK: - Set active connection
    func setActive(id: UUID) {
        guard connections.contains(where: { $0.id == id }) else { return }
        activeConnectionID = id
    }

    // MARK: - List directory on active connection
    func listDirectory(_ path: String) async throws -> [RemoteFileItem] {
        guard let conn = activeConnection else {
            throw RemoteProviderError.notConnected
        }
        let items = try await conn.provider.listDirectory(path)
        // Update current path
        if let idx = connections.firstIndex(where: { $0.id == conn.id }) {
            connections[idx].currentPath = path
        }
        return items
    }

    // MARK: - Navigate to parent directory
    func navigateUp() async throws -> [RemoteFileItem] {
        guard let conn = activeConnection else {
            throw RemoteProviderError.notConnected
        }
        let parent = (conn.currentPath as NSString).deletingLastPathComponent
        let normalizedParent = parent.isEmpty ? "/" : parent
        return try await listDirectory(normalizedParent)
    }

    // MARK: - Provider factory
    private func createProvider(for proto: RemoteProtocol) -> any RemoteFileProvider {
        switch proto {
        case .sftp:
            return SFTPFileProvider()
        case .ftp:
            return FTPFileProvider()
        case .smb, .afp:
            // SMB/AFP use macOS native mount — no custom provider needed
            // Return FTP as stub; actual SMB uses NetworkMountService
            log.warning("[RemoteManager] \(proto.rawValue) uses native mount, not RemoteFileProvider")
            return FTPFileProvider()
        }
    }

    // MARK: - Update server's last connection result in store
    private func updateServerResult(_ server: RemoteServer, result: ConnectionResult) {
        var updated = server
        updated.lastConnected = Date()
        updated.lastResult = result
        RemoteServerStore.shared.update(updated)
    }

    // MARK: - Classify connection error into ConnectionResult
    private func classifyError(_ error: Error) -> ConnectionResult {
        let msg = error.localizedDescription.lowercased()
        if let providerErr = error as? RemoteProviderError {
            switch providerErr {
            case .authFailed: return .authFailed
            case .notConnected, .notImplemented: return .error
            case .invalidURL: return .error
            case .listingFailed: return .error
            }
        }
        if msg.contains("timeout") || msg.contains("timed out") { return .timeout }
        if msg.contains("refused") || msg.contains("connection refused") { return .refused }
        if msg.contains("auth") || msg.contains("password") || msg.contains("denied") { return .authFailed }
        return .error
    }
}
