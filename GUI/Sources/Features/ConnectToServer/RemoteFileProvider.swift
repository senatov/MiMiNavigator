// RemoteFileProvider.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Protocol and implementations for remote file access.
//   SFTPFileProvider — Citadel (SPM: https://github.com/orlandos-nl/Citadel).
//   FTPFileProvider  — built-in URLSession/curl, no dependencies.

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
    /// Downloads a remote file to a local temp URL. Returns the local URL.
    @concurrent func downloadFile(remotePath: String) async throws -> URL
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
#if canImport(Citadel)
/// SFTP via Citadel (NIOSSH). Uses real Citadel API:
///   SSHClient.connect(host:port:authenticationMethod:hostKeyValidator:reconnect:)
final class SFTPFileProvider: RemoteFileProvider, @unchecked Sendable {

    private(set) var isConnected = false
    private(set) var mountPath = ""

    private var sshClient: SSHClient?
    private var sftpClient: SFTPClient?

    // MARK: - Connect
    @concurrent func connect(host: String, port: Int, user: String, password: String, remotePath: String) async throws {
        log.debug("""
        [SFTP] connect host=\(host) port=\(port) user=\(user) \
        remotePath=\(remotePath) pwdProvided=\(!password.isEmpty)
        """)
        do {
            // Real Citadel API — no SSHClientSettings, direct connect call
            let client = try await SSHClient.connect(
                host: host,
                port: port,
                authenticationMethod: .passwordBased(username: user, password: password),
                hostKeyValidator: .acceptAnything(),   // TODO: replace with known-hosts in prod
                reconnect: .never,
                algorithms: .all   // enables legacy algorithms for broader server compat
            )
            let sftp = try await client.openSFTP()
            sshClient  = client
            sftpClient = sftp
            mountPath  = Self.buildMountPath(scheme: "sftp", user: user, host: host,
                                             port: port, remotePath: remotePath)
            isConnected = true
            log.info("[SFTP] connected → \(mountPath)")
        } catch {
            let ns = error as NSError
            log.error("""
            [SFTP] FAILED host=\(host):\(port) user=\(user)
            domain=\(ns.domain) code=\(ns.code) desc=\(ns.localizedDescription) raw=\(error)
            """)
            throw error
        }
    }

    // MARK: - List Directory
    @concurrent func listDirectory(_ path: String) async throws -> [RemoteFileItem] {
        guard let sftp = sftpClient else { throw RemoteProviderError.notConnected }
        let dirPath = path.isEmpty ? "/" : path
        // Citadel: SFTPMessage.Name has .components: [SFTPPathComponent] (public)
        // .path is internal computed — do NOT use it
        let names = try await sftp.listDirectory(atPath: dirPath)
        let items: [RemoteFileItem] = names.flatMap { nameMsg in
            nameMsg.components.compactMap { comp in
                let name = comp.filename
                guard name != "." && name != ".." else { return nil }
                let fullPath = dirPath.hasSuffix("/") ? "\(dirPath)\(name)"
                                                      : "\(dirPath)/\(name)"
                // POSIX S_IFDIR = 0o040000
                let isDir: Bool
                if let perms = comp.attributes.permissions {
                    isDir = (perms & 0o170000) == 0o040000
                } else {
                    isDir = comp.longname.hasPrefix("d")
                }
                let size  = Int64(comp.attributes.size ?? 0)
                let mdate = comp.attributes.accessModificationTime?.modificationTime
                return RemoteFileItem(name: name, path: fullPath,
                                      isDirectory: isDir, size: size, modified: mdate)
            }
        }
        log.debug("[SFTP] listed \(items.count) items at \(dirPath)")
        return items
    }

    // MARK: - Download File
    /// Downloads remote file → /tmp/MiMiSFTP/<name>, returns local URL.
    /// Uses Citadel SFTPClient.openFile + SFTPFile.readAll — no getFile helper needed.
    @concurrent func downloadFile(remotePath: String) async throws -> URL {
        guard let sftp = sftpClient else { throw RemoteProviderError.notConnected }
        let fileName = (remotePath as NSString).lastPathComponent
        let tmpDir   = FileManager.default.temporaryDirectory
            .appendingPathComponent("MiMiSFTP", isDirectory: true)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        let localURL = tmpDir.appendingPathComponent(fileName)
        log.info("[SFTP] downloading '\(remotePath)' → '\(localURL.path)'")
        // Open remote file read-only, read entire content as ByteBuffer, convert to Data
        let buffer = try await sftp.withFile(filePath: remotePath, flags: .read) { file in
            try await file.readAll()
        }
        let data = Data(buffer: buffer)
        try data.write(to: localURL)
        log.info("[SFTP] download OK size=\(data.count) → '\(localURL.lastPathComponent)'")
        return localURL
    }

    // MARK: - Disconnect
    @concurrent func disconnect() async {
        do { try await sftpClient?.close() }
        catch { log.warning("[SFTP] close error: \(error)") }
        sshClient   = nil
        sftpClient  = nil
        isConnected = false
        mountPath   = ""
        log.info("[SFTP] disconnected")
    }

    // MARK: - Build clean mount path  (sftp://user@host[:port]/remotePath)
    private static func buildMountPath(scheme: String, user: String,
                                       host: String, port: Int,
                                       remotePath: String) -> String {
        let portStr = (scheme == "sftp" && port == 22) ||
                      (scheme == "ftp"  && port == 21) ? "" : ":\(port)"
        let path = remotePath.isEmpty ? "" :
                   remotePath.hasPrefix("/") ? remotePath : "/\(remotePath)"
        return "\(scheme)://\(user)@\(host)\(portStr)\(path)"
    }
}
#else
// MARK: - SFTPFileProvider stub (Citadel not in SPM yet)
final class SFTPFileProvider: RemoteFileProvider, @unchecked Sendable {
    private(set) var isConnected = false
    private(set) var mountPath   = ""
    @concurrent func connect(host: String, port: Int, user: String, password: String, remotePath: String) async throws {
        log.error("[SFTP] Citadel not available — add SPM dependency")
        throw RemoteProviderError.notImplemented
    }
    @concurrent func listDirectory(_ path: String) async throws -> [RemoteFileItem] {
        throw RemoteProviderError.notImplemented
    }
    @concurrent func downloadFile(remotePath: String) async throws -> URL {
        throw RemoteProviderError.notImplemented
    }
    @concurrent func disconnect() async { isConnected = false; mountPath = "" }
}
#endif

// MARK: - FTPFileProvider
final class FTPFileProvider: RemoteFileProvider, @unchecked Sendable {

    private(set) var isConnected = false
    private(set) var mountPath   = ""
    private var baseURL: URL?
    private var ftpUser: String     = ""
    private var ftpPassword: String = ""

    private static func buildMountPath(scheme: String, user: String,
                                       host: String, port: Int,
                                       remotePath: String) -> String {
        let portStr = (scheme == "sftp" && port == 22) ||
                      (scheme == "ftp"  && port == 21) ? "" : ":\(port)"
        let path = remotePath.isEmpty ? "" :
                   remotePath.hasPrefix("/") ? remotePath : "/\(remotePath)"
        return "\(scheme)://\(user)@\(host)\(portStr)\(path)"
    }

    // MARK: - Connect
    @concurrent func connect(host: String, port: Int, user: String, password: String, remotePath: String) async throws {
        var components = URLComponents()
        components.scheme = "ftp"
        components.host   = host
        components.port   = port != 21 ? port : nil
        components.path   = remotePath.hasPrefix("/") ? remotePath : "/\(remotePath)"
        guard let url = components.url else { throw RemoteProviderError.invalidURL }
        baseURL     = url
        ftpUser     = user
        ftpPassword = password
        _ = try await listDirectory(remotePath.isEmpty ? "/" : remotePath)
        mountPath   = Self.buildMountPath(scheme: "ftp", user: user, host: host,
                                          port: port, remotePath: remotePath)
        isConnected = true
        log.info("[FTP] connected → \(mountPath)")
    }

    // MARK: - List Directory (curl — URLSession FTP is deprecated on macOS)
    @concurrent func listDirectory(_ path: String) async throws -> [RemoteFileItem] {
        guard let base = baseURL else { throw RemoteProviderError.notConnected }
        guard !path.contains("://") else {
            log.error("[FTP] rejecting mangled path='\(path)'")
            throw RemoteProviderError.invalidURL
        }
        let dirPath  = path.hasPrefix("/") ? path : "/\(path)"
        let listPath = dirPath.hasSuffix("/") ? dirPath : dirPath + "/"
        var comps    = URLComponents(url: base, resolvingAgainstBaseURL: false)
        comps?.path     = listPath
        comps?.user     = ftpUser
        comps?.password = ftpPassword
        guard let dirURL = comps?.url else { throw RemoteProviderError.invalidURL }
        let raw   = try await curlFTPList(url: dirURL)
        let items = parseFTPListing(raw, basePath: path)
        log.debug("[FTP] listed \(items.count) items at \(path)")
        return items
    }

    @concurrent private func curlFTPList(url: URL) async throws -> String {
        let scheme = url.scheme ?? ""
        guard scheme == "ftp" || scheme == "ftps",
              let host = url.host, !host.isEmpty
        else { throw RemoteProviderError.invalidURL }
        let urlStr = url.absoluteString
        return try await withCheckedThrowingContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
                proc.arguments     = ["-s", "--max-time", "15", urlStr]
                let out = Pipe(), err = Pipe()
                proc.standardOutput = out; proc.standardError = err
                do { try proc.run() } catch {
                    cont.resume(throwing: RemoteProviderError.listingFailed("curl: \(error)"))
                    return
                }
                proc.waitUntilExit()
                let raw = String(data: out.fileHandleForReading.readDataToEndOfFile(),
                                 encoding: .utf8) ?? ""
                if proc.terminationStatus != 0 {
                    let e = String(data: err.fileHandleForReading.readDataToEndOfFile(),
                                   encoding: .utf8) ?? ""
                    log.warning("[FTP] curl exit=\(proc.terminationStatus): \(e.prefix(200))")
                }
                cont.resume(returning: raw)
            }
        }
    }

    // MARK: - Disconnect
    @concurrent func disconnect() async {
        isConnected = false; baseURL = nil
        ftpUser = ""; ftpPassword = ""; mountPath = ""
        log.info("[FTP] disconnected")
    }

    // MARK: - Download (FTP — not yet implemented)
    @concurrent func downloadFile(remotePath: String) async throws -> URL {
        log.error("[FTP] downloadFile not implemented")
        throw RemoteProviderError.notImplemented
    }

    private func parseFTPListing(_ raw: String, basePath: String) -> [RemoteFileItem] {
        raw.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .compactMap { line -> RemoteFileItem? in
                let parts = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                guard parts.count >= 9 else { return nil }
                let name = parts[8...].joined(separator: " ")
                guard name != "." && name != ".." else { return nil }
                let isDir = parts[0].hasPrefix("d")
                let size  = Int64(parts[4]) ?? 0
                let path  = basePath.hasSuffix("/") ? "\(basePath)\(name)" : "\(basePath)/\(name)"
                return RemoteFileItem(name: name, path: path, isDirectory: isDir,
                                      size: size, permissions: parts[0])
            }
    }
}

// MARK: - NoOpRemoteFileProvider  (SMB/AFP use native OS mount)
final class NoOpRemoteFileProvider: RemoteFileProvider, @unchecked Sendable {
    private(set) var isConnected = false
    private(set) var mountPath   = ""
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
    @concurrent func disconnect() async {}
}
