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

    private var autoConnectAttemptedServerIDs: Set<UUID> = []
    private var connectInFlightKeys: Set<String> = []

    var isConnected: Bool {
        !connections.isEmpty
    }

    var activeConnection: RemoteConnection? {
        guard let id = activeConnectionID else { return connections.first }
        return connections.first { $0.id == id }
    }

    private init() {}

    private func connectionKey(for server: RemoteServer) -> String {
        let normalizedHost = Self.normalizeHost(server.host)
        let normalizedPath = Self.normalizeRemotePath(server.remotePath)
        return "\(server.remoteProtocol.rawValue)|\(normalizedHost)|\(server.port)|\(server.user)|\(normalizedPath)"
    }

    private func beginConnectAttempt(for server: RemoteServer, source: String) -> Bool {
        let key = connectionKey(for: server)
        guard !connectInFlightKeys.contains(key) else {
            log.warning("[RemoteConnectionManager] skip duplicate connect source=\(source) server=\(server.displayName) key=\(key)")
            return false
        }

        connectInFlightKeys.insert(key)
        log.debug("[RemoteConnectionManager] begin connect source=\(source) server=\(server.displayName) key=\(key)")
        return true
    }

    private func finishConnectAttempt(for server: RemoteServer, source: String) {
        let key = connectionKey(for: server)
        let removed = connectInFlightKeys.remove(key) != nil
        log.debug(
            "[RemoteConnectionManager] finish connect source=\(source) server=\(server.displayName) removed=\(removed) key=\(key)")
    }

    // MARK: - Password Lookup
    private func loadSavedPassword(for server: RemoteServer) -> String {
        let password = RemoteServerKeychain.loadPassword(for: server)
        let hasPassword = !password.isEmpty
        log.debug("[RemoteConnectionManager] keychain lookup server=\(server.displayName) hasPassword=\(hasPassword)")
        return password
    }

    private func hasSavedPassword(for server: RemoteServer) -> Bool {
        !loadSavedPassword(for: server).isEmpty
    }

    // MARK: - Connection Lookup
    private func indexOfConnection(id: UUID) -> Int? {
        connections.firstIndex { $0.id == id }
    }

    private func requireActiveConnection(function: String = #function) throws -> RemoteConnection {
        guard let connection = activeConnection else {
            log.warning("\(function) failed: no active connection")
            throw RemoteProviderError.notConnected
        }
        return connection
    }

    private func startPath(for server: RemoteServer) -> String {
        let normalizedPath = Self.normalizeRemotePath(server.remotePath)
        return normalizedPath.isEmpty ? "/" : normalizedPath
    }

    // MARK: - Auto-connect
    func connectOnStartIfNeeded() async {
        let serversToConnect = RemoteServerStore.shared.servers.filter { $0.connectOnStart }
        log.info("\(#function) auto-connecting \(serversToConnect.count) server(s)")
        guard !serversToConnect.isEmpty else { return }

        for server in serversToConnect {
            if autoConnectAttemptedServerIDs.contains(server.id) {
                log.debug("[RemoteConnectionManager] auto-connect already processed for \(server.displayName)")
                continue
            }

            autoConnectAttemptedServerIDs.insert(server.id)
            await connectOnStartIfPossible(server: server)
        }

        log.info(#function + " done")
    }

    private func connectOnStartIfPossible(server: RemoteServer) async {
        guard supportsAutoConnectOnStart(for: server.remoteProtocol) else {
            let detail = unsupportedProtocolDetail(for: server)
            log.warning(
                "[RemoteConnectionManager] auto-connect skipped for \(server.displayName): unsupported protocol=\(server.remoteProtocol.rawValue)"
            )
            log.warning("[RemoteConnectionManager] diagnostic: \(detail)")
            updateServerResult(server, result: .error, errorDetail: detail)
            return
        }

        guard !requiresDeferredStartupConnect(for: server) else {
            log.info("[RemoteConnectionManager] auto-connect deferred for \(server.displayName): startup password access disabled")
            return
        }

        let password = loadSavedPassword(for: server)
        guard !password.isEmpty else {
            log.info("[RemoteConnectionManager] auto-connect deferred for \(server.displayName): no saved password loaded at startup")
            return
        }

        await connect(to: server, password: password)
    }

    private func supportsAutoConnectOnStart(for proto: RemoteProtocol) -> Bool {
        switch proto {
            case .sftp, .ftp:
                return true
            default:
                return false
        }
    }

    private func requiresDeferredStartupConnect(for server: RemoteServer) -> Bool {
        supportsAutoConnectOnStart(for: server.remoteProtocol)
    }

    private func unsupportedProtocolDetail(for server: RemoteServer) -> String {
        "SMB is not implemented in this build. host=\(server.host) port=\(server.port) user=\(server.user) path=\(server.remotePath.isEmpty ? "/" : server.remotePath)"
    }

    // MARK: - Connect
    func connect(to server: RemoteServer, password: String) async {
        log.info("\(#function) \(server.displayName) via \(server.remoteProtocol.rawValue)")

        guard beginConnectAttempt(for: server, source: #function) else { return }
        defer { finishConnectAttempt(for: server, source: #function) }

        if let existingConnection = connection(for: server) {
            reuseConnection(existingConnection)
            return
        }

        if password.isEmpty {
            log.warning("[RemoteConnectionManager] connect requested with empty password for \(server.displayName)")
        }

        guard let provider = createProvider(for: server.remoteProtocol) else {
            let detail = unsupportedProtocolDetail(for: server)
            log.warning("[RemoteConnectionManager] connect skipped for \(server.displayName): unsupported protocol=\(server.remoteProtocol.rawValue)")
            log.warning("[RemoteConnectionManager] diagnostic: \(detail)")
            updateServerResult(server, result: .error, errorDetail: detail)
            return
        }

        await connectWithNewProvider(provider, to: server, password: password)
    }

    private func reuseConnection(_ connection: RemoteConnection) {
        log.warning("\(#function) already connected")
        log.warning("\(#function) reusing existing connection")
        activeConnectionID = connection.id
    }

    private func connectWithNewProvider(_ provider: any RemoteFileProvider, to server: RemoteServer, password: String) async {
        do {
            log.debug(
                "[RemoteConnectionManager] provider.connect host=\(server.host) port=\(server.port) user=\(server.user) proto=\(server.remoteProtocol.rawValue)"
            )
            try await provider.connect(
                host: server.host,
                port: server.port,
                user: server.user,
                password: password,
                remotePath: server.remotePath
            )

            let connection = makeConnection(server: server, provider: provider)
            appendConnectedServer(connection, originalServer: server)
        } catch {
            handleConnectionFailure(error, server: server)
        }
    }

    private func makeConnection(server: RemoteServer, provider: any RemoteFileProvider) -> RemoteConnection {
        RemoteConnection(
            id: UUID(),
            server: server,
            provider: provider,
            connectedAt: Date(),
            currentPath: startPath(for: server)
        )
    }

    private func appendConnectedServer(_ connection: RemoteConnection, originalServer: RemoteServer) {
        connections.append(connection)
        activeConnectionID = connection.id
        updateServerResult(originalServer, result: .success, errorDetail: nil)

        log.info("\(#function) connected: \(connection.displayName)")
        log.info("\(#function) id=\(connection.id)")
        log.info("\(#function) total=\(connections.count)")
    }

    private func handleConnectionFailure(_ error: Error, server: RemoteServer) {
        let nsError = error as NSError
        let result = classifyError(error)
        updateServerResult(server, result: result, errorDetail: error.localizedDescription)

        if result == .authFailed {
            log.warning(
                "[RemoteConnectionManager] authentication failed for \(server.displayName); stored password may be missing or invalid")
        }

        log.error("[RemoteConnectionManager] connect FAILED host=\(server.host):\(server.port)")
        log.error("[RemoteConnectionManager] proto=\(server.remoteProtocol.rawValue)")
        log.error("[RemoteConnectionManager] domain=\(nsError.domain) code=\(nsError.code)")
        log.error("[RemoteConnectionManager] classified=\(result.rawValue)")
        log.error("[RemoteConnectionManager] desc=\(nsError.localizedDescription)")
    }

    // MARK: - Disconnect
    func disconnect(id: UUID) async {
        guard let connectionIndex = indexOfConnection(id: id) else { return }

        let connection = connections[connectionIndex]
        await disconnectConnection(connection)
        removeConnection(at: connectionIndex)
        updateActiveConnectionAfterDisconnect(id: id)

        log.info("\(#function) \(connection.displayName)")
        log.info("\(#function) remaining=\(connections.count)")
    }

    private func disconnectConnection(_ connection: RemoteConnection) async {
        await connection.provider.disconnect()
    }

    private func removeConnection(at index: Int) {
        connections.remove(at: index)
    }

    private func updateActiveConnectionAfterDisconnect(id: UUID) {
        guard activeConnectionID == id else { return }
        activeConnectionID = connections.first?.id
    }

    func disconnectAll() async {
        for connection in connections {
            await disconnectConnection(connection)
        }

        connections.removeAll()
        activeConnectionID = nil
        log.info("\(#function) all closed")
    }

    // MARK: - Active connection
    func setActive(id: UUID) {
        guard connections.contains(where: { $0.id == id }) else { return }
        activeConnectionID = id
    }

    func hasConnection(for server: RemoteServer) -> Bool {
        connection(for: server) != nil
    }

    func isConnected(to server: RemoteServer) -> Bool {
        hasConnection(for: server)
    }

    func connection(for server: RemoteServer) -> RemoteConnection? {
        let normalizedServerHost = Self.normalizeHost(server.host)
        let normalizedServerPath = Self.normalizeRemotePath(server.remotePath)

        return connections.first { connection in
            let normalizedConnectionHost = Self.normalizeHost(connection.server.host)
            let normalizedConnectionPath = Self.normalizeRemotePath(connection.server.remotePath)

            return normalizedConnectionHost == normalizedServerHost
                && connection.server.port == server.port
                && connection.server.remoteProtocol == server.remoteProtocol
                && connection.server.user == server.user
                && normalizedConnectionPath == normalizedServerPath
        }
    }

    // MARK: - Remote operations
    func listDirectory(_ path: String) async throws -> [RemoteFileItem] {
        log.debug("\(#function) active=\(activeConnection?.displayName ?? "none")")
        let connection = try requireActiveConnection()
        let items = try await connection.provider.listDirectory(path)
        updateCurrentPath(path, for: connection.id)
        return items
    }

    private func updateCurrentPath(_ path: String, for connectionID: UUID) {
        guard let idx = indexOfConnection(id: connectionID) else { return }
        connections[idx].currentPath = path
    }

    func downloadFile(remotePath: String) async throws -> URL {
        log.debug(#function + " active=\(activeConnection?.displayName ?? "none")")
        let connection = try requireActiveConnection()
        log.info("\(#function) '\(remotePath)'")
        return try await connection.provider.downloadFile(remotePath: remotePath)
    }

    func navigateUp() async throws -> [RemoteFileItem] {
        let connection = try requireActiveConnection()
        let parentPath = parentPath(for: connection.currentPath)
        return try await listDirectory(parentPath)
    }

    private func parentPath(for path: String) -> String {
        let parent = (path as NSString).deletingLastPathComponent
        return parent.isEmpty ? "/" : parent
    }

    // MARK: - Helpers
    private static func normalizeHost(_ host: String) -> String {
        host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func normalizeRemotePath(_ path: String) -> String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "/" }
        return trimmed
    }

    private func createProvider(for proto: RemoteProtocol) -> (any RemoteFileProvider)? {
        log.debug("\(#function)(\(proto))")

        switch proto {
            case .sftp:
                return SFTPFileProvider()
            case .ftp:
                return FTPFileProvider()
            default:
                log.warning("[RemoteConnectionManager] provider unavailable for protocol=\(proto.rawValue)")
                log.warning("[RemoteConnectionManager] only FTP and SFTP providers are currently implemented")
                return nil
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

        if isAuthenticationError(message: message, raw: raw) {
            return .authFailed
        }

        return .error
    }

    private func isAuthenticationError(message: String, raw: String) -> Bool {
        message.contains("auth")
            || message.contains("password")
            || message.contains("denied")
            || raw.contains("allauthenticationoptionsfailed")
    }
}
