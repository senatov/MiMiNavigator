// SFTPFileProvider.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: SFTP via Citadel (NIOSSH) — connect, list, download, upload, mkdir, delete, disconnect.
//   Extracted from RemoteFileProvider.swift for clean code / single responsibility.

import FileModelKit
import Foundation
import NIOCore

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

    private func requireSSHClient(function: String = #function) throws -> SSHClient {
        guard let client = sshClient, isConnected else {
            log.warning("[SFTP] \(function) failed: SSH client not connected")
            throw RemoteProviderError.notConnected
        }
        return client
    }


    // MARK: - Upload to Remote

    @concurrent func uploadToRemote(localPath: String, remotePath: String, recursive: Bool) async throws {
        let sftp = try requireSFTPClient()
        let localURL = URL(fileURLWithPath: localPath)
        let normalizedRemotePath = normalizeRemotePath(remotePath)

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: localURL.path, isDirectory: &isDirectory) else {
            throw NSError(
                domain: "SFTPFileProvider",
                code: 1001,
                userInfo: [NSLocalizedDescriptionKey: "Local path does not exist: \(localPath)"]
            )
        }

        if isDirectory.boolValue {
            guard recursive else {
                throw NSError(
                    domain: "SFTPFileProvider",
                    code: 1002,
                    userInfo: [NSLocalizedDescriptionKey: "Directory upload requires recursive=true"]
                )
            }
            log.info("[SFTP] recursive upload '\(localPath)' → '\(normalizedRemotePath)'")
            try await uploadDirectory(from: localURL, to: normalizedRemotePath, sftp: sftp)
            return
        }

        log.info("[SFTP] upload '\(localPath)' → '\(normalizedRemotePath)'")
        try await uploadRegularFile(from: localURL, to: normalizedRemotePath, sftp: sftp)
    }



    // MARK: - Create Directory

    @concurrent func createDirectory(at remotePath: String) async throws {
        let sftp = try requireSFTPClient()
        let normalizedRemotePath = normalizeRemotePath(remotePath)

        log.info("[SFTP] mkdir '\(normalizedRemotePath)'")
        try await sftp.createDirectory(atPath: normalizedRemotePath)
    }



    // MARK: - Delete Remote Item

    @concurrent func deleteItem(at remotePath: String, recursive: Bool = true) async throws {
        _ = try requireSFTPClient()
        let ssh = try requireSSHClient()
        let normalizedRemotePath = normalizeRemotePath(remotePath)
        let escapedPath = shellEscapedPath(normalizedRemotePath)

        let command = recursive ? "rm -rf -- \(escapedPath)" : "rm -f -- \(escapedPath)"
        log.info("[SFTP] delete '\(normalizedRemotePath)' recursive=\(recursive)")
        _ = try await ssh.executeCommand(command, mergeStreams: true)
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

    private func shellEscapedPath(_ path: String) -> String {
        let escaped = path.replacingOccurrences(of: "'", with: "'\\''")
        return "'\(escaped)'"
    }

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


    private func ensureRemoteParentDirectoryExists(for remotePath: String, sftp: SFTPClient) async throws {
        let normalizedRemotePath = normalizeRemotePath(remotePath)
        let parentPath = (normalizedRemotePath as NSString).deletingLastPathComponent
        let normalizedParentPath = normalizeRemotePath(parentPath)

        guard normalizedParentPath != normalizedRemotePath, normalizedParentPath != "/" else { return }

        let components = normalizedParentPath
            .split(separator: "/")
            .map(String.init)

        var currentPath = ""
        for component in components {
            currentPath += "/\(component)"
            do {
                try await sftp.createDirectory(atPath: currentPath)
            } catch {
                // Ignore "already exists"-style failures; a later write will reveal real problems.
            }
        }
    }

    private func localFileData(at localURL: URL) throws -> Data {
        try Data(contentsOf: localURL)
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

    private func uploadRegularFile(from localURL: URL, to remotePath: String, sftp: SFTPClient) async throws {
        try await ensureRemoteParentDirectoryExists(for: remotePath, sftp: sftp)
        let data = try localFileData(at: localURL)
        let buffer = ByteBuffer(data: data)
        let normalizedRemotePath = normalizeRemotePath(remotePath)

        try await sftp.withFile(
            filePath: normalizedRemotePath,
            flags: [.read, .write, .forceCreate]
        ) { file in
            try await file.write(buffer, at: 0)
        }
    }

    private func uploadDirectory(from localURL: URL, to remotePath: String, sftp: SFTPClient) async throws {
        let normalizedRemotePath = normalizeRemotePath(remotePath)

        do {
            try await sftp.createDirectory(atPath: normalizedRemotePath)
        } catch {
            // Ignore if it already exists; subsequent uploads will fail if the path is unusable.
        }

        let childURLs = try FileManager.default.contentsOfDirectory(
            at: localURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        for childURL in childURLs {
            let childName = childURL.lastPathComponent
            let childRemotePath = appendRemoteComponent(childName, to: normalizedRemotePath)
            let resourceValues = try childURL.resourceValues(forKeys: [.isDirectoryKey])

            if resourceValues.isDirectory == true {
                try await uploadDirectory(from: childURL, to: childRemotePath, sftp: sftp)
            } else {
                try await uploadRegularFile(from: childURL, to: childRemotePath, sftp: sftp)
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

    @concurrent func uploadToRemote(localPath: String, remotePath: String, recursive: Bool) async throws {
        throw RemoteProviderError.notImplemented
    }

    @concurrent func createDirectory(at remotePath: String) async throws {
        throw RemoteProviderError.notImplemented
    }

    @concurrent func deleteItem(at remotePath: String, recursive: Bool = true) async throws {
        throw RemoteProviderError.notImplemented
    }

    @concurrent func disconnect() async {
        isConnected = false
        mountPath = ""
    }
}
#endif
