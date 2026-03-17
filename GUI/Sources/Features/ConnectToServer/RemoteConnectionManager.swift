    // RemoteConnectionManager.swift
    // MiMiNavigator
    //
    // Copyright © 2026 Senatov. All rights reserved.
    // Description: Singleton managing active remote connections (SFTP / FTP).
    //   Owns RemoteFileProvider instances, handles connect/disconnect lifecycle,
    //   publishes connection state for UI (status bar, panel integration).
    //   Thread-safe: @MainActor for UI state, provider calls via Task.

    import FileModelKit
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
                let connection = RemoteConnection(
                    id: UUID(),
                    server: server,
                    provider: provider,
                    connectedAt: Date(),
                    currentPath: server.remotePath.isEmpty ? "/" : server.remotePath
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
                    """)
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
            log.info("[RemoteManager] disconnected: \(conn.displayName) id=\(conn.id) remaining=\(connections.count)")
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

        // MARK: - Find existing connection for server
        func connection(for server: RemoteServer) -> RemoteConnection? {
            connections.first {
                $0.server.host == server.host && $0.server.port == server.port && $0.server.remoteProtocol == server.remoteProtocol
            }
        }

        // MARK: - List directory on active connection
        func listDirectory(_ path: String) async throws -> [RemoteFileItem] {
            log.debug("[RemoteManager] listDirectory path=\(path) active=\(activeConnection?.displayName ?? "none")")
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

        // MARK: - Download file from active connection
        /// Downloads remotePath → tmp, returns local URL for NSWorkspace.open().
        func downloadFile(remotePath: String) async throws -> URL {
            guard let conn = activeConnection else { throw RemoteProviderError.notConnected }
            log.info("[RemoteManager] downloadFile '\(remotePath)'")
            return try await conn.provider.downloadFile(remotePath: remotePath)
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
            log.debug(#function + "(\(proto))")
            switch proto {
                case .sftp:
                    return SFTPFileProvider()
                case .ftp:
                    return FTPFileProvider()
                case .smb, .afp:
                    // SMB/AFP use macOS native mount — RemoteFileProvider not involved
                    log.warning("\(#function) \(proto.rawValue) uses native mount, returning NoOp provider")
                    return NoOpRemoteFileProvider(reason: "\(proto.rawValue) uses native macOS mount")
            }
        }

        // MARK: - Update server result in store (success + fail unified)
        private func updateServerResult(_ server: RemoteServer, result: ConnectionResult, errorDetail: String?) {
            log.debug("\(#function) \(server.displayName) → \(result.rawValue)")
            var updated = server
            updated.lastConnected = Date()
            updated.lastResult = result
            updated.lastErrorDetail = errorDetail
            RemoteServerStore.shared.update(updated)
        }

        // MARK: - Transfer files with console (upload or download, multi-file)
        /// Entry point for any multi-file remote transfer.
        /// Opens RemoteTransferConsole, runs transfers sequentially, auto-closes on done.
        func transferFiles(
            items: [(remotePath: String, localURL: URL, size: Int64)],
            direction: RemoteTransferDirection,
            serverLabel: String
        ) async {
            guard let conn = activeConnection else {
                log.error("[RemoteManager] transferFiles — no active connection")
                return
            }
            let transferItems = items.map { item in
                RemoteTransferItem(remotePath: item.remotePath,
                                   localURL:   item.localURL,
                                   size:       item.size)
            }
            let progress = RemoteTransferProgress(
                direction:   direction,
                serverLabel: serverLabel,
                items:       transferItems
            )
            // Open console window immediately on MainActor
            await MainActor.run { RemoteTransferConsole.shared.open(progress: progress) }

            for item in progress.items {
                if progress.isCancelled { break }
                await MainActor.run { progress.startItem(id: item.id, name: item.name) }
                do {
                    switch direction {
                    case .download:
                        // Download: remote → local
                        let localURL = try await conn.provider.downloadFile(remotePath: item.remotePath)
                        let size = (try? localURL.resourceValues(forKeys: [.fileSizeKey]).fileSize)
                                        .map { Int64($0) } ?? item.size
                        await MainActor.run {
                            progress.updateItem(id: item.id, transferred: size)
                            progress.completeItem(id: item.id, success: true)
                        }
                    case .upload:
                        // Upload: local → remote (SFTPClient.writeFile when available)
                        log.warning("[RemoteManager] upload not yet implemented for \(item.name)")
                        await MainActor.run {
                            progress.completeItem(id: item.id, success: false,
                                                  error: "Upload not yet implemented")
                        }
                    }
                } catch {
                    await MainActor.run {
                        progress.completeItem(id: item.id, success: false,
                                              error: error.localizedDescription)
                    }
                }
            }
            await MainActor.run { progress.complete() }
        }

        // MARK: - Convenience: download single file with console
        func downloadFileWithConsole(remotePath: String, size: Int64 = 0) async throws -> URL {
            guard let conn = activeConnection else { throw RemoteProviderError.notConnected }
            let serverLabel = AppState.remoteOrigin(from: conn.provider.mountPath)
                .replacingOccurrences(of: "sftp://", with: "SFTP ")
                .replacingOccurrences(of: "ftp://", with: "FTP ")
            let localURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("MiMiSFTP")
                .appendingPathComponent((remotePath as NSString).lastPathComponent)
            await transferFiles(
                items: [(remotePath: remotePath, localURL: localURL, size: size)],
                direction: .download,
                serverLabel: serverLabel
            )
            return localURL
        }

        // MARK: - Classify connection error into ConnectionResult
        private func classifyError(_ error: Error) -> ConnectionResult {
            log.debug(#function + "(\(error))")
            let raw = String(describing: error).lowercased()
            let msg = error.localizedDescription.lowercased()
            if let providerErr = error as? RemoteProviderError {
                switch providerErr {
                    case .authFailed: return .authFailed
                    case .notConnected, .notImplemented: return .error
                    case .invalidURL: return .error
                    case .listingFailed: return .error
                }
            }
            if msg.contains("timeout") || msg.contains("timed out") {
                log.debug(#function + ": Detected timeout error")
                return .timeout
            }
            if msg.contains("refused") || msg.contains("connection refused") {
                log.debug(#function + ": Detected connection refused error")
                return .refused
            }
            if msg.contains("auth") ||
               msg.contains("password") ||
               msg.contains("denied") ||
               raw.contains("allauthenticationoptionsfailed") {
                log.debug(#function + ": Detected authentication error")
                return .authFailed
            }
            return .error
        }
    }
