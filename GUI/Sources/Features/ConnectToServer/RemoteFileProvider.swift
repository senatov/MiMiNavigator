    // RemoteFileProvider.swift
    // MiMiNavigator
    //
    // Copyright © 2026 Senatov. All rights reserved.
    // Description: Protocol and implementations for remote file access.
    //   SFTPFileProvider — Citadel (SPM: https://github.com/orlandos-nl/Citadel).
    //   FTPFileProvider  — built-in URLSession, no dependencies.

    import Foundation
    import FileModelKit
    #if canImport(Citadel)
    import Citadel
    #endif

    // MARK: - RemoteFileProvider
    protocol RemoteFileProvider: AnyObject, Sendable {
        var isConnected: Bool { get }
        var mountPath: String { get }
        @concurrent func connect(host: String, port: Int, user: String, password: String, remotePath: String) async throws
        @concurrent func listDirectory(_ path: String) async throws -> [RemoteFileItem]
        @concurrent func disconnect() async
    }

    // MARK: - RemoteProviderError
    enum RemoteProviderError: LocalizedError {
        case notConnected
        case invalidURL
        case authFailed
        case listingFailed(String)
        case notImplemented

        var errorDescription: String? {
            switch self {
            case .notConnected:           return "Not connected to remote server"
            case .invalidURL:             return "Invalid server URL"
            case .authFailed:             return "Authentication failed"
            case .listingFailed(let msg): return "Directory listing failed: \(msg)"
            case .notImplemented:         return "Protocol not yet implemented"
            }
        }
    }

    // MARK: - SFTPFileProvider
    /// SFTP via Citadel (NIOSSH).
    /// SPM: https://github.com/orlandos-nl/Citadel — add to project before using.
    #if canImport(Citadel)
    final class SFTPFileProvider: RemoteFileProvider, @unchecked Sendable {

        private(set) var isConnected = false
        private(set) var mountPath = ""

        private var sshClient: SSHClient?
        private var sftpClient: SFTPClient?

        // MARK: - Connect
        @concurrent func connect(host: String, port: Int, user: String, password: String, remotePath: String) async throws {
            log.debug("""
            [SFTP] connect requested
            host=\(host)
            port=\(port)
            user=\(user)
            remotePath=\(remotePath)
            passwordProvided=\(!password.isEmpty)
            """)

            let settings = SSHClientSettings(
                host: host,
                port: port,
                authenticationMethod: { .passwordBased(username: user, password: password) },
                hostKeyValidator: .acceptAnything()
            )

            do {
                let client = try await SSHClient.connect(to: settings)
                let sftp = try await client.openSFTP()

                sshClient = client
                sftpClient = sftp

                mountPath = buildMountPath(
                    scheme: "sftp",
                    user: user,
                    host: host,
                    port: port,
                    remotePath: remotePath
                )

                isConnected = true
                log.info("[SFTP] connected to \(mountPath)")
            } catch {
                let nsError = error as NSError
                log.error("""
                [SFTP] connect FAILED
                host=\(host)
                port=\(port)
                user=\(user)
                domain=\(nsError.domain)
                code=\(nsError.code)
                desc=\(nsError.localizedDescription)
                raw=\(error)
                """)
                throw error
            }
        }

        private func buildMountPath(
            scheme: String,
            user: String,
            host: String,
            port: Int,
            remotePath: String
        ) -> String {
            let displayPort = (scheme == "sftp" && port != 22) ||
                              (scheme == "ftp" && port != 21)
                              ? ":\(port)"
                              : ""
            let path = remotePath.isEmpty ? "/" :
                       (remotePath.hasPrefix("/") ? remotePath : "/\(remotePath)")
            return "\(scheme)://\(user)@\(host)\(displayPort)\(path)"
        }

        // MARK: - List Directory
        @concurrent func listDirectory(_ path: String) async throws -> [RemoteFileItem] {
            guard let sftp = sftpClient else { throw RemoteProviderError.notConnected }
            let dirPath = path.isEmpty ? "/" : path
            let nameMessages = try await sftp.listDirectory(atPath: dirPath)
            // Each SFTPMessage.Name contains .components: [SFTPPathComponent]
            let items: [RemoteFileItem] = nameMessages.flatMap { nameMsg in
                nameMsg.components.compactMap { component in
                    let name = component.filename
                    guard name != "." && name != ".." else { return nil }
                    let fullPath = dirPath.hasSuffix("/") ? "\(dirPath)\(name)" : "\(dirPath)/\(name)"
                    // Check POSIX directory bit (0o040000 = S_IFDIR)
                    let isDir: Bool
                    if let perms = component.attributes.permissions {
                        isDir = (perms & 0o170000) == 0o040000
                    } else {
                        isDir = component.longname.hasPrefix("d")
                    }
                    let size = Int64(component.attributes.size ?? 0)
                    let mdate = component.attributes.accessModificationTime?.modificationTime
                    return RemoteFileItem(name: name, path: fullPath, isDirectory: isDir, size: size, modified: mdate)
                }
            }
            log.debug("[SFTP] listed \(items.count) items at \(dirPath)")
            return items
        }

        // MARK: - Disconnect
        @concurrent func disconnect() async {
            log.debug("[SFTP] disconnect requested")
            do {
                try await sftpClient?.close()
            } catch {
                log.warning("[SFTP] error during SFTP close: \(error)")
            }
            sshClient = nil
            sftpClient = nil
            isConnected = false
            mountPath = ""
            log.info("[SFTP] disconnected")
        }
    }
    #else
    // MARK: - SFTPFileProvider (stub without Citadel)
    /// Stub: Citadel not yet added to SPM. Add the dependency, then remove this stub.
    final class SFTPFileProvider: RemoteFileProvider, @unchecked Sendable {
        private(set) var isConnected = false
        private(set) var mountPath = ""

        @concurrent func connect(host: String, port: Int, user: String, password: String, remotePath: String) async throws {
            log.error("[SFTP] Citadel not available — add SPM dependency first")
            throw RemoteProviderError.notImplemented
        }

        @concurrent func listDirectory(_ path: String) async throws -> [RemoteFileItem] {
            throw RemoteProviderError.notImplemented
        }

        @concurrent func disconnect() async {
            isConnected = false
            mountPath = ""
        }
    }
    #endif

    // MARK: - FTPFileProvider
    /// FTP via URLSession — no external dependencies required.
    final class FTPFileProvider: RemoteFileProvider, @unchecked Sendable {

        private(set) var isConnected = false
        private(set) var mountPath = ""

        private var baseURL: URL?
        private var ftpUser: String = ""
        private var ftpPassword: String = ""

        private func buildMountPath(
            scheme: String,
            user: String,
            host: String,
            port: Int,
            remotePath: String
        ) -> String {
            let displayPort = (scheme == "sftp" && port != 22) ||
                              (scheme == "ftp" && port != 21)
                              ? ":\(port)"
                              : ""
            let path = remotePath.isEmpty ? "/" :
                       (remotePath.hasPrefix("/") ? remotePath : "/\(remotePath)")
            return "\(scheme)://\(user)@\(host)\(displayPort)\(path)"
        }

        // MARK: - Connect
        @concurrent func connect(host: String, port: Int, user: String, password: String, remotePath: String) async throws {
            log.debug("""
            [FTP] connect requested
            host=\(host)
            port=\(port)
            user=\(user)
            remotePath=\(remotePath)
            passwordProvided=\(!password.isEmpty)
            """)

            var components = URLComponents()
            components.scheme = "ftp"
            components.host = host
            components.port = port != 21 ? port : nil
            components.path = remotePath.hasPrefix("/") ? remotePath : "/\(remotePath)"
            guard let url = components.url else { throw RemoteProviderError.invalidURL }
            baseURL = url
            ftpUser = user
            ftpPassword = password
            _ = try await listDirectory(remotePath.isEmpty ? "/" : remotePath)
            mountPath = buildMountPath(
                scheme: "ftp",
                user: user,
                host: host,
                port: port,
                remotePath: remotePath
            )
            isConnected = true
            log.info("[FTP] connected to \(mountPath)")
        }

        // MARK: - List Directory (via curl — URLSession FTP support is broken/deprecated on macOS)
        @concurrent func listDirectory(_ path: String) async throws -> [RemoteFileItem] {
            guard let base = baseURL else { throw RemoteProviderError.notConnected }
            // guard: reject if path somehow contains a full URL (ftp://...) — would produce curl exit=3
            guard !path.contains("://"), !path.contains("ftp:"), !path.contains("sftp:") else {
                log.error("\(#function) rejecting mangled path='\(path)' — looks like full URL not a dir path")
                throw RemoteProviderError.invalidURL
            }
            let dirPath = path.hasPrefix("/") ? path : "/\(path)"
            // Ensure trailing slash so curl lists the directory (not tries to download a file)
            let listPath = dirPath.hasSuffix("/") ? dirPath : dirPath + "/"

            var components = URLComponents(url: base, resolvingAgainstBaseURL: false)
            components?.path = listPath
            components?.user = ftpUser
            components?.password = ftpPassword
            guard let dirURL = components?.url else { throw RemoteProviderError.invalidURL }

            let raw = try await curlFTPList(url: dirURL)
            let items = parseFTPListing(raw, basePath: path)
            log.debug("\(#function) listed \(items.count) items at \(path) (raw \(raw.count) chars)")
            return items
        }

        // MARK: - curl-based FTP LIST (reliable, unlike URLSession FTP)
        @concurrent private func curlFTPList(url: URL) async throws -> String {
            // exit=3 = CURLE_URL_MALFORMAT — validate before handing off to curl
            let scheme = url.scheme ?? ""
            guard scheme == "ftp" || scheme == "ftps" else {
                log.error("\(#function) bad scheme '\(scheme)' in url=\(url.absoluteString) — aborting curl")
                throw RemoteProviderError.invalidURL
            }
            guard let host = url.host, !host.isEmpty else {
                log.error("\(#function) empty host in url=\(url.absoluteString) — aborting curl")
                throw RemoteProviderError.invalidURL
            }
            let urlStr = url.absoluteString
            guard urlStr.hasPrefix("ftp://") || urlStr.hasPrefix("ftps://") else {
                log.error("\(#function) url doesn't start with ftp(s):// — got '\(urlStr.prefix(30))' — aborting curl")
                throw RemoteProviderError.invalidURL
            }
            log.debug("\(#function) curl → \(urlStr)")
            return try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
                    process.arguments = [
                        "-s",
                        "--max-time", "15",
                        urlStr
                    ]
                    let outPipe = Pipe()
                    let errPipe = Pipe()
                    process.standardOutput = outPipe
                    process.standardError = errPipe
                    do { try process.run() } catch {
                        continuation.resume(throwing: RemoteProviderError.listingFailed("curl launch: \(error.localizedDescription)"))
                        return
                    }
                    process.waitUntilExit()
                    let data = outPipe.fileHandleForReading.readDataToEndOfFile()
                    let raw = String(data: data, encoding: .utf8) ?? ""
                    if process.terminationStatus != 0 {
                        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                        let errStr = String(data: errData, encoding: .utf8) ?? ""
                        log.warning("\(#function) curl exit=\(process.terminationStatus) url=\(urlStr): \(errStr.prefix(200))")
                        // Still try to parse — partial listing may be valid
                    }
                    continuation.resume(returning: raw)
                }
            }
        }

        // MARK: - Disconnect
        @concurrent func disconnect() async {
            log.debug("[FTP] disconnect requested")
            isConnected = false
            baseURL = nil
            ftpUser = ""
            ftpPassword = ""
            mountPath = ""
            log.info("[FTP] disconnected")
        }

        // MARK: - Parse Unix-style FTP LIST output (vsftpd / proftpd)
        private func parseFTPListing(_ raw: String, basePath: String) -> [RemoteFileItem] {
            raw.components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .compactMap { line -> RemoteFileItem? in
                    let parts = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                    guard parts.count >= 9 else { return nil }
                    let perms = parts[0]
                    let size  = Int64(parts[4]) ?? 0
                    let name  = parts[8...].joined(separator: " ")
                    guard name != "." && name != ".." else { return nil }
                    let isDir = perms.hasPrefix("d")
                    let path  = basePath.hasSuffix("/") ? "\(basePath)\(name)" : "\(basePath)/\(name)"
                    return RemoteFileItem(name: name, path: path, isDirectory: isDir, size: size, permissions: perms)
                }
        }
    }

    // MARK: - NoOpRemoteFileProvider
    /// Used for protocols that use native OS mount (SMB, AFP) — not handled via RemoteFileProvider.
    /// Throws `notImplemented` on any call so callers fail loudly instead of silently misbehaving.
    final class NoOpRemoteFileProvider: RemoteFileProvider, @unchecked Sendable {
        private(set) var isConnected = false
        private(set) var mountPath = ""
        private let reason: String

        init(reason: String) {
            self.reason = reason
            log.debug("[NoOpProvider] created — \(reason)")
        }

        @concurrent func connect(host: String, port: Int, user: String, password: String, remotePath: String) async throws {
            log.error("[NoOpProvider] connect called — \(reason)")
            throw RemoteProviderError.notImplemented
        }

        @concurrent func listDirectory(_ path: String) async throws -> [RemoteFileItem] {
            log.error("[NoOpProvider] listDirectory called — \(reason)")
            throw RemoteProviderError.notImplemented
        }

        @concurrent func disconnect() async {
            log.debug("[NoOpProvider] disconnect (noop) — \(reason)")
        }
    }
