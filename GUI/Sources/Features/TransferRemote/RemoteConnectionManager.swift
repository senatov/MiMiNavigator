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
    var onConnectionActivated: ((RemoteConnection) -> Void)?

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
        let serversToConnect = RemoteServerStore.shared.servers.filter { shouldAutoConnectOnStart($0) }
        log.info("\(#function) auto-connecting \(serversToConnect.count) server(s)")
        guard !serversToConnect.isEmpty else { return }

        for server in serversToConnect {
            if autoConnectAttemptedServerIDs.contains(server.id) {
                log.debug("[RemoteConnectionManager] auto-connect already processed for \(server.displayName)")
                continue
            }

            autoConnectAttemptedServerIDs.insert(server.id)

            guard supportsAutoConnectOnStart(for: server.remoteProtocol) else {
                let detail = unsupportedProtocolDetail(for: server)
                log.info(
                    "[RemoteConnectionManager] auto-connect disabled for \(server.displayName): protocol=\(server.remoteProtocol.rawValue) is not supported in this build"
                )
                updateServerResult(server, result: .error, errorDetail: detail)
                continue
            }

            await connectOnStartIfPossible(server: server)
        }

        log.info(#function + " done")
    }

    private func connectOnStartIfPossible(server: RemoteServer) async {

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
            case .sftp, .ftp, .smb:
                return true
            default:
                return false
        }
    }

    private func shouldAutoConnectOnStart(_ server: RemoteServer) -> Bool {
        guard server.connectOnStart else { return false }
        guard !connectionIsActive(for: server) else {
            log.debug("[RemoteConnectionManager] auto-connect skipped for \(server.displayName): already connected")
            return false
        }
        return true
    }

    private func connectionIsActive(for server: RemoteServer) -> Bool {
        connection(for: server) != nil
    }

    private func requiresDeferredStartupConnect(for server: RemoteServer) -> Bool {
        false
    }

    private func unsupportedProtocolDetail(for server: RemoteServer) -> String {
        "Protocol \(server.remoteProtocol.rawValue) is not implemented in this build. host=\(server.host) port=\(server.port) user=\(server.user) path=\(server.remotePath.isEmpty ? "/" : server.remotePath)"
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
        log.info("[RemoteConnectionManager] reusing existing connection for \(connection.displayName)")
        activeConnectionID = connection.id
        notifyConnectionActivated(connection)
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
        notifyConnectionActivated(connection)

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
        disableConnectOnStartAfterManualDisconnect(for: connection.server)

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

    private func disableConnectOnStartAfterManualDisconnect(for server: RemoteServer) {
        guard server.connectOnStart else {
            log.debug("[RemoteConnectionManager] manual disconnect keeps connectOnStart=false for \(server.displayName)")
            return
        }

        var updated = server
        updated.connectOnStart = false
        updated.lastErrorDetail = nil
        RemoteServerStore.shared.update(updated)
        log.info("[RemoteConnectionManager] manual disconnect disabled reconnect on start for \(server.displayName)")
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
        guard let connection = connections.first(where: { $0.id == id }) else { return }
        notifyConnectionActivated(connection)
    }

    func hasConnection(for server: RemoteServer) -> Bool {
        connection(for: server) != nil
    }

    func isConnected(to server: RemoteServer) -> Bool {
        hasConnection(for: server) || hasMountedSystemConnection(for: server)
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

    private func hasMountedSystemConnection(for server: RemoteServer) -> Bool {
        guard server.remoteProtocol == .smb else { return false }
        guard let mountPointPath = expectedSMBMountPointPath(for: server) else { return false }
        return Self.isSMBMounted(atPath: mountPointPath)
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

    private func expectedSMBMountPointPath(for server: RemoteServer) -> String? {
        let trimmed = Self.normalizeRemotePath(server.remotePath)
        let components = trimmed.split(separator: "/", omittingEmptySubsequences: true)
        guard let share = components.first else { return nil }
        let decodedShare = String(share).removingPercentEncoding ?? String(share)
        guard !decodedShare.isEmpty else { return nil }
        return "/Volumes/" + decodedShare
    }

    private static func isSMBMounted(atPath path: String) -> Bool {
        guard FileManager.default.fileExists(atPath: path) else { return false }

        let process = Process()
        let outputPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/sbin/mount")
        process.standardOutput = outputPipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            log.warning("[RemoteConnectionManager] SMB mount probe failed for \(path): \(error.localizedDescription)")
            return false
        }

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8) ?? ""
        return output.contains(" on \(path) (smbfs")
    }

    private func createProvider(for proto: RemoteProtocol) -> (any RemoteFileProvider)? {
        log.debug("\(#function)(\(proto))")

        switch proto {
            case .sftp:
                return SFTPFileProvider()
            case .ftp:
                return FTPFileProvider()
            case .smb:
                return SMBFileProvider()
            default:
                log.warning("[RemoteConnectionManager] provider unavailable for protocol=\(proto.rawValue)")
                log.warning("[RemoteConnectionManager] only FTP, SFTP, and SMB providers are currently implemented")
                return nil
        }
    }

    private func notifyConnectionActivated(_ connection: RemoteConnection) {
        onConnectionActivated?(connection)
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
