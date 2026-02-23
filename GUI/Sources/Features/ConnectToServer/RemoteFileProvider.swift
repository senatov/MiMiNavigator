// RemoteFileProvider.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Protocol and implementations for remote file access.
//   SFTPFileProvider — Citadel (SPM: https://github.com/orlandos-nl/Citadel).
//   FTPFileProvider  — built-in URLSession, no dependencies.

import Foundation
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
        let client = try await SSHClient.connect(
            host: host,
            authenticationMethod: .passwordBased(username: user, password: password),
            hostKeyValidator: .acceptAnything(),
            reconnect: .never
        )
        let sftp = try await client.openSFTP()
        sshClient = client
        sftpClient = sftp
        let displayPort = port != 22 ? ":\(port)" : ""
        mountPath = "sftp://\(user)@\(host)\(displayPort)\(remotePath.isEmpty ? "/" : remotePath)"
        isConnected = true
        log.info("[SFTP] connected to \(mountPath)")
    }

    // MARK: - List Directory
    @concurrent func listDirectory(_ path: String) async throws -> [RemoteFileItem] {
        guard let sftp = sftpClient else { throw RemoteProviderError.notConnected }
        let dirPath = path.isEmpty ? "/" : path
        let entries = try await sftp.listDirectory(atPath: dirPath)
        let items: [RemoteFileItem] = entries.compactMap { entry in
            let name = entry.filename
            guard name != "." && name != ".." else { return nil }
            let fullPath = dirPath.hasSuffix("/") ? "\(dirPath)\(name)" : "\(dirPath)/\(name)"
            let isDir  = entry.attributes.type == .directory
            let size   = Int64(entry.attributes.size ?? 0)
            let mdate: Date? = entry.attributes.modificationTime.map { Date(timeIntervalSince1970: TimeInterval($0)) }
            return RemoteFileItem(name: name, path: fullPath, isDirectory: isDir, size: size, modified: mdate)
        }
        log.debug("[SFTP] listed \(items.count) items at \(dirPath)")
        return items
    }

    // MARK: - Disconnect
    @concurrent func disconnect() async {
        try? await sftpClient?.close()
        sftpClient = nil
        sshClient = nil
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

    // MARK: - Connect
    @concurrent func connect(host: String, port: Int, user: String, password: String, remotePath: String) async throws {
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
        let displayPort = port != 21 ? ":\(port)" : ""
        mountPath = "ftp://\(host)\(displayPort)\(remotePath.isEmpty ? "/" : remotePath)"
        isConnected = true
        log.info("[FTP] connected to \(mountPath)")
    }

    // MARK: - List Directory (via curl — URLSession FTP support is broken/deprecated on macOS)
    @concurrent func listDirectory(_ path: String) async throws -> [RemoteFileItem] {
        guard let base = baseURL else { throw RemoteProviderError.notConnected }
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
        log.debug("[FTP] listed \(items.count) items at \(path) (raw \(raw.count) chars)")
        return items
    }

    // MARK: - curl-based FTP LIST (reliable, unlike URLSession FTP)
    private func curlFTPList(url: URL) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
                process.arguments = [
                    "-s",              // silent
                    "--max-time", "15",
                    url.absoluteString
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
                    let err = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                    log.warning("[FTP] curl exit=\(process.terminationStatus): \(err.prefix(200))")
                    // Still try to parse — partial listing may be valid
                }
                continuation.resume(returning: raw)
            }
        }
    }

    // MARK: - Disconnect
    @concurrent func disconnect() async {
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
