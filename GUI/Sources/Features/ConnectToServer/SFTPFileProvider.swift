<<<<<<< HEAD
// SFTPFileProvider.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: SFTP via Citadel (NIOSSH) — connect, list, download, disconnect.
//   Extracted from RemoteFileProvider.swift for clean code / single responsibility.

import FileModelKit
import Foundation

#if canImport(Citadel)
import Citadel
#endif


// MARK: - SFTPFileProvider

#if canImport(Citadel)
/// SFTP via Citadel (NIOSSH). Downloads use the active SFTP session.
final class SFTPFileProvider: RemoteFileProvider, @unchecked Sendable {

    private(set) var isConnected = false
    private(set) var mountPath = ""
    private var sshClient: SSHClient?
    private var sftpClient: SFTPClient?


    // MARK: - Session helpers

    private func requireSFTPClient(function: String = #function) throws -> SFTPClient {
        guard let client = sftpClient, isConnected else {
            log.warning("[SFTP] \(function) failed: not connected")
            throw RemoteProviderError.notConnected
        }
        return client
    }

    private func updateConnectedSession(sshClient: SSHClient, sftpClient: SFTPClient, mountPath: String) {
        self.sshClient = sshClient
        self.sftpClient = sftpClient
        self.mountPath = mountPath
        isConnected = true
    }

    private func resetSession() {
        sshClient = nil
        sftpClient = nil
        isConnected = false
        mountPath = ""
    }



    // MARK: - Connect

    @concurrent func connect(host: String, port: Int, user: String, password: String, remotePath: String) async throws {
        log.debug("[SFTP] connect host=\(host) port=\(port)")
        log.debug("[SFTP] user=\(user) remotePath=\(remotePath)")
        log.debug("[SFTP] password provided=\(!password.isEmpty)")

        do {
            let client = try await SSHClient.connect(
                host: host,
                port: port,
                authenticationMethod: .passwordBased(username: user, password: password),
                hostKeyValidator: .acceptAnything(),
                reconnect: .never,
                algorithms: .all
            )
            let sftp = try await client.openSFTP()
            let path = Self.buildMountPath(scheme: "sftp", user: user, host: host, port: port, remotePath: remotePath)

            updateConnectedSession(sshClient: client, sftpClient: sftp, mountPath: path)
            log.info("[SFTP] connected → \(path)")
        } catch {
            let ns = error as NSError
            log.error("[SFTP] connect failed host=\(host):\(port)")
            log.error("[SFTP] user=\(user)")
            log.error("[SFTP] domain=\(ns.domain) code=\(ns.code)")
            log.error("[SFTP] desc=\(ns.localizedDescription)")
            throw error
        }
    }



    // MARK: - List Directory

    @concurrent func listDirectory(_ path: String) async throws -> [RemoteFileItem] {
        let sftp = try requireSFTPClient()
        let dirPath = normalizeRemotePath(path)
        let names = try await sftp.listDirectory(atPath: dirPath)
        var items: [RemoteFileItem] = []

        for nameMsg in names {
            for comp in nameMsg.components {
                let name = comp.filename
                if name == "." || name == ".." {
                    continue
                }

                let fullPath = fullRemotePath(name: name, in: dirPath)
                let isDir = isDirectoryEntry(comp) || comp.longname.hasPrefix("d")
                let size = fileSize(from: comp)
                let mdate = modificationDate(from: comp)
                let item = RemoteFileItem(
                    name: name,
                    path: fullPath,
                    isDirectory: isDir,
                    size: size,
                    modified: mdate
                )
                items.append(item)
            }
        }

        log.debug("[SFTP] listed \(items.count) items at \(dirPath)")
        return items
    }



    // MARK: - Download File

    @concurrent func downloadFile(remotePath: String) async throws -> URL {
        _ = try requireSFTPClient()
        let normalizedPath = normalizeRemotePath(remotePath)
        let fileName = (normalizedPath as NSString).lastPathComponent
        let localURL = try makeTemporaryDownloadURL(fileName: fileName)

        log.info("[SFTP] downloading '\(normalizedPath)'")
        log.info("[SFTP] local target '\(localURL.path)'")

        try await downloadToLocal(remotePath: normalizedPath, localPath: localURL.path, recursive: false)

        let size = localFileSize(at: localURL)
        log.info("[SFTP] download OK size=\(size)")
        log.info("[SFTP] saved as '\(localURL.lastPathComponent)'")
        return localURL
    }



    // MARK: - Download to Local (file or directory)

    @concurrent func downloadToLocal(remotePath: String, localPath: String, recursive: Bool) async throws {
        let sftp = try requireSFTPClient()
        let normalizedPath = normalizeRemotePath(remotePath)
        let localURL = URL(fileURLWithPath: localPath)
        let attrs = try await sftp.getAttributes(at: normalizedPath)
        let isDirectory = isDirectoryAttributes(attrs)
        if isDirectory {
            guard recursive else {
                throw RemoteProviderError.downloadFailed("Directory download requires recursive=true")
            }
            log.info("[SFTP] recursive download '\(normalizedPath)' → '\(localPath)'")
            try await downloadDirectory(from: normalizedPath, to: localURL, sftp: sftp)
            return
        }
        log.info("[SFTP] download '\(normalizedPath)' → '\(localPath)'")
        try await downloadRegularFile(from: normalizedPath, to: localURL, sftp: sftp)
    }



    // MARK: - Disconnect

    @concurrent func disconnect() async {
        do {
            try await sftpClient?.close()
        } catch {
            log.warning("[SFTP] close error: \(error)")
        }

        resetSession()
        log.info("[SFTP] disconnected")
    }



    // MARK: - Private helpers

    private func normalizeRemotePath(_ path: String) -> String {
        let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else { return "/" }
        return trimmedPath.hasPrefix("/") ? trimmedPath : "/\(trimmedPath)"
    }

    private func fullRemotePath(name: String, in directoryPath: String) -> String {
        let normalizedDirectory = normalizeRemotePath(directoryPath)
        return normalizedDirectory == "/" ? "/\(name)" : "\(normalizedDirectory)/\(name)"
    }

    private func isDirectoryEntry(_ entry: SFTPPathComponent) -> Bool {
        isDirectoryAttributes(entry.attributes)
    }

    private func fileSize(from entry: SFTPPathComponent) -> Int64 {
        Int64(entry.attributes.size ?? 0)
    }

    private func modificationDate(from entry: SFTPPathComponent) -> Date? {
        entry.attributes.accessModificationTime?.modificationTime
    }

    private func isDirectoryAttributes(_ attributes: SFTPFileAttributes) -> Bool {
        guard let permissions = attributes.permissions else { return false }
        return (permissions & 0o170000) == 0o040000
    }


    private func appendRemoteComponent(_ name: String, to basePath: String) -> String {
        let normalizedBase = normalizeRemotePath(basePath)
        return normalizedBase == "/" ? "/\(name)" : "\(normalizedBase)/\(name)"
    }

    private func removeExistingFileIfNeeded(at localURL: URL) {
        guard FileManager.default.fileExists(atPath: localURL.path) else { return }
        try? FileManager.default.removeItem(at: localURL)
    }

    private func makeTemporaryDownloadURL(fileName: String) throws -> URL {
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent("MiMiSFTP", isDirectory: true)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)

        let localURL = tmpDir.appendingPathComponent(fileName)
        removeExistingFileIfNeeded(at: localURL)
        return localURL
    }

    private func localFileSize(at localURL: URL) -> Int64 {
        (try? FileManager.default.attributesOfItem(atPath: localURL.path)[.size] as? Int64) ?? 0
    }



    private func ensureParentDirectoryExists(for localURL: URL) throws {
        let parentURL = localURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parentURL, withIntermediateDirectories: true)
    }



    private func downloadRegularFile(from remotePath: String, to localURL: URL, sftp: SFTPClient) async throws {
        try ensureParentDirectoryExists(for: localURL)
        let data = try await readRemoteFileData(remotePath: remotePath, sftp: sftp)
        try data.write(to: localURL, options: .atomic)
    }

    private func readRemoteFileData(remotePath: String, sftp: SFTPClient) async throws -> Data {
        let normalizedPath = normalizeRemotePath(remotePath)
        let attributes = try await sftp.getAttributes(at: normalizedPath)
        let remoteSize = Int(attributes.size ?? 0)

        log.debug("[SFTP] readRemoteFileData path=\(normalizedPath)")
        log.debug("[SFTP] reported size=\(remoteSize)")

        guard remoteSize > 0 else {
            return Data()
        }

        let buffer = try await sftp.withFile(filePath: normalizedPath, flags: .read) { file in
            try await file.read(from: 0, length: UInt32(remoteSize))
        }

        let data = Data(buffer.readableBytesView)
        log.debug("[SFTP] received bytes=\(data.count)")
        return data
    }

    private func downloadDirectory(from remotePath: String, to localURL: URL, sftp: SFTPClient) async throws {
        try FileManager.default.createDirectory(at: localURL, withIntermediateDirectories: true)
        let entries = try await listDirectory(normalizeRemotePath(remotePath))
        for entry in entries {
            let childRemotePath = fullRemotePath(name: entry.name, in: remotePath)
            let childLocalURL = localURL.appendingPathComponent(entry.name, isDirectory: entry.isDirectory)
            if entry.isDirectory {
                try await downloadDirectory(from: childRemotePath, to: childLocalURL, sftp: sftp)
            } else {
                try await downloadRegularFile(from: childRemotePath, to: childLocalURL, sftp: sftp)
            }
        }
    }



    // MARK: - Build mount path

    private static func buildMountPath(scheme: String, user: String, host: String, port: Int, remotePath: String) -> String {
        let portStr = (scheme == "sftp" && port == 22) || (scheme == "ftp" && port == 21) ? "" : ":\(port)"
        let trimmedPath = remotePath.trimmingCharacters(in: .whitespacesAndNewlines)
        let path = trimmedPath.isEmpty ? "" : trimmedPath.hasPrefix("/") ? trimmedPath : "/\(trimmedPath)"
        return "\(scheme)://\(user)@\(host)\(portStr)\(path)"
    }
}
#else
// MARK: - SFTPFileProvider stub (Citadel not available)
final class SFTPFileProvider: RemoteFileProvider, @unchecked Sendable {
    private(set) var isConnected = false
    private(set) var mountPath = ""
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

    @concurrent func downloadToLocal(remotePath: String, localPath: String, recursive: Bool) async throws {
        throw RemoteProviderError.notImplemented
    }

    @concurrent func disconnect() async {
        isConnected = false
        mountPath = ""
    }
}
#endif
||||||| de9fccb7
=======
// SFTPFileProvider.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: SFTP via Citadel (NIOSSH) — connect, list, download, disconnect.
//   Extracted from RemoteFileProvider.swift for clean code / single responsibility.

import FileModelKit
import Foundation

#if canImport(Citadel)
import Citadel
#endif


// MARK: - SFTPFileProvider

#if canImport(Citadel)
/// SFTP via Citadel (NIOSSH). Downloads use the active SFTP session.
final class SFTPFileProvider: RemoteFileProvider, @unchecked Sendable {

    private(set) var isConnected = false
    private(set) var mountPath = ""
    private var sshClient: SSHClient?
    private var sftpClient: SFTPClient?



    // MARK: - Connect

    @concurrent func connect(host: String, port: Int, user: String, password: String, remotePath: String) async throws {
        log.debug("[SFTP] connect host=\(host) port=\(port) user=\(user) remotePath=\(remotePath) pwdProvided=\(!password.isEmpty)")
        do {
            let client = try await SSHClient.connect(
                host: host,
                port: port,
                authenticationMethod: .passwordBased(username: user, password: password),
                hostKeyValidator: .acceptAnything(),
                reconnect: .never,
                algorithms: .all
            )
            let sftp = try await client.openSFTP()
            sshClient = client
            sftpClient = sftp
            mountPath = Self.buildMountPath(scheme: "sftp", user: user, host: host, port: port, remotePath: remotePath)
            isConnected = true
            log.info("[SFTP] connected → \(mountPath)")
        } catch {
            let ns = error as NSError
            log.error("[SFTP] FAILED host=\(host):\(port) user=\(user) domain=\(ns.domain) code=\(ns.code) desc=\(ns.localizedDescription)")
            throw error
        }
    }



    // MARK: - List Directory

    @concurrent func listDirectory(_ path: String) async throws -> [RemoteFileItem] {
        guard let sftp = sftpClient else { throw RemoteProviderError.notConnected }
        let dirPath = path.isEmpty ? "/" : path
        let names = try await sftp.listDirectory(atPath: dirPath)
        let items: [RemoteFileItem] = names.flatMap { nameMsg in
            nameMsg.components.compactMap { comp in
                let name = comp.filename
                guard name != "." && name != ".." else { return nil }
                let fullPath = dirPath.hasSuffix("/") ? "\(dirPath)\(name)" : "\(dirPath)/\(name)"
                let isDir: Bool
                if let perms = comp.attributes.permissions {
                    isDir = (perms & 0o170000) == 0o040000
                } else {
                    isDir = comp.longname.hasPrefix("d")
                }
                let size = Int64(comp.attributes.size ?? 0)
                let mdate = comp.attributes.accessModificationTime?.modificationTime
                return RemoteFileItem(name: name, path: fullPath, isDirectory: isDir, size: size, modified: mdate)
            }
        }
        log.debug("[SFTP] listed \(items.count) items at \(dirPath)")
        return items
    }



    // MARK: - Download File

    @concurrent func downloadFile(remotePath: String) async throws -> URL {
        guard isConnected else { throw RemoteProviderError.notConnected }
        let normalizedPath = normalizeRemotePath(remotePath)
        let fileName = (normalizedPath as NSString).lastPathComponent
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent("MiMiSFTP", isDirectory: true)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        let localURL = tmpDir.appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: localURL.path) {
            try? FileManager.default.removeItem(at: localURL)
        }
        log.info("[SFTP] downloading '\(normalizedPath)' → '\(localURL.path)'")
        try await downloadToLocal(remotePath: normalizedPath, localPath: localURL.path, recursive: false)
        let size = (try? FileManager.default.attributesOfItem(atPath: localURL.path)[.size] as? Int64) ?? 0
        log.info("[SFTP] download OK size=\(size) → '\(localURL.lastPathComponent)'")
        return localURL
    }



    // MARK: - Download to Local (file or directory)

    @concurrent func downloadToLocal(remotePath: String, localPath: String, recursive: Bool) async throws {
        guard let sftp = sftpClient, isConnected else { throw RemoteProviderError.notConnected }
        let normalizedPath = normalizeRemotePath(remotePath)
        let localURL = URL(fileURLWithPath: localPath)
        let attrs = try await sftp.getAttributes(at: normalizedPath)
        let isDirectory = {
            guard let permissions = attrs.permissions else { return false }
            return (permissions & 0o170000) == 0o040000
        }()
        if isDirectory {
            guard recursive else {
                throw RemoteProviderError.downloadFailed("Directory download requires recursive=true")
            }
            log.info("[SFTP] recursive download '\(normalizedPath)' → '\(localPath)'")
            try await downloadDirectory(from: normalizedPath, to: localURL, sftp: sftp)
            return
        }
        log.info("[SFTP] download '\(normalizedPath)' → '\(localPath)'")
        try await downloadRegularFile(from: normalizedPath, to: localURL, sftp: sftp)
    }



    // MARK: - Disconnect

    @concurrent func disconnect() async {
        do { try await sftpClient?.close() } catch { log.warning("[SFTP] close error: \(error)") }
        sshClient = nil
        sftpClient = nil
        isConnected = false
        mountPath = ""
        log.info("[SFTP] disconnected")
    }



    // MARK: - Private helpers

    private func normalizeRemotePath(_ path: String) -> String {
        guard !path.isEmpty else { return "/" }
        return path.hasPrefix("/") ? path : "/\(path)"
    }



    private func appendRemoteComponent(_ name: String, to basePath: String) -> String {
        let normalizedBase = normalizeRemotePath(basePath)
        return normalizedBase == "/" ? "/\(name)" : "\(normalizedBase)/\(name)"
    }



    private func ensureParentDirectoryExists(for localURL: URL) throws {
        let parentURL = localURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parentURL, withIntermediateDirectories: true)
    }



    private func downloadRegularFile(from remotePath: String, to localURL: URL, sftp: SFTPClient) async throws {
        try ensureParentDirectoryExists(for: localURL)
        let buffer = try await sftp.withFile(filePath: remotePath, flags: .read) { file in
            try await file.read(from: 0, length: .max)
        }
        let data = Data(buffer.readableBytesView)
        try data.write(to: localURL, options: .atomic)
    }



    private func downloadDirectory(from remotePath: String, to localURL: URL, sftp: SFTPClient) async throws {
        try FileManager.default.createDirectory(at: localURL, withIntermediateDirectories: true)
        let entries = try await listDirectory(remotePath)
        for entry in entries {
            let childRemotePath = appendRemoteComponent(entry.name, to: remotePath)
            let childLocalURL = localURL.appendingPathComponent(entry.name, isDirectory: entry.isDirectory)
            if entry.isDirectory {
                try await downloadDirectory(from: childRemotePath, to: childLocalURL, sftp: sftp)
            } else {
                try await downloadRegularFile(from: childRemotePath, to: childLocalURL, sftp: sftp)
            }
        }
    }



    // MARK: - Build mount path

    private static func buildMountPath(scheme: String, user: String, host: String, port: Int, remotePath: String) -> String {
        let portStr = (scheme == "sftp" && port == 22) || (scheme == "ftp" && port == 21) ? "" : ":\(port)"
        let path = remotePath.isEmpty ? "" : remotePath.hasPrefix("/") ? remotePath : "/\(remotePath)"
        return "\(scheme)://\(user)@\(host)\(portStr)\(path)"
    }
}
#else
// MARK: - SFTPFileProvider stub (Citadel not available)
final class SFTPFileProvider: RemoteFileProvider, @unchecked Sendable {
    private(set) var isConnected = false
    private(set) var mountPath = ""
    @concurrent func connect(host: String, port: Int, user: String, password: String, remotePath: String) async throws {
        log.error("[SFTP] Citadel not available — add SPM dependency")
        throw RemoteProviderError.notImplemented
    }
    @concurrent func listDirectory(_ path: String) async throws -> [RemoteFileItem] { throw RemoteProviderError.notImplemented }
    @concurrent func downloadFile(remotePath: String) async throws -> URL { throw RemoteProviderError.notImplemented }
    @concurrent func downloadToLocal(remotePath: String, localPath: String, recursive: Bool) async throws { throw RemoteProviderError.notImplemented }
    @concurrent func disconnect() async { isConnected = false; mountPath = "" }
}
#endif
>>>>>>> ab57e9238eb905e903ce46d112f9ce00fbdecd17
