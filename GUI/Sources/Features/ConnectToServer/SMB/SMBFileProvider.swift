//
//  SMBFileProvider.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 07.04.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//


import Foundation
import FileModelKit

#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif


// MARK: - SMBFileProvider
final class SMBFileProvider: @unchecked Sendable, RemoteFileProvider {
    enum SMBProviderError: LocalizedError {
        case missingSession
        case invalidMountURL
        case invalidRemotePath(String)
        case mountFailed(String)
        case commandFailed(String)
        case unsupportedRecursiveUpload(String)

        var errorDescription: String? {
            switch self {
                case .missingSession:
                    return "SMB session is not connected"
                case .invalidMountURL:
                    return "SMB mount point URL is invalid"
                case .invalidRemotePath(let path):
                    return "SMB remote path must include a share name, for example /Share. Current path: \(path)"
                case .mountFailed(let message):
                    return "SMB mount failed: \(message)"
                case .commandFailed(let message):
                    return "SMB command failed: \(message)"
                case .unsupportedRecursiveUpload(let path):
                    return "Recursive SMB upload is not supported for this path: \(path)"
            }
        }
    }

    private struct SMBSession: Sendable {
        let host: String
        let port: Int
        let user: String
        let shareRootPath: String
        let mountRootURL: URL
        let mountPointURL: URL
        let browseURL: URL
        let didMountShare: Bool
    }

    private let stateQueue = DispatchQueue(label: "MiMiNavigator.SMBFileProvider.state")
    private var session: SMBSession?
    static let defaultCommandTimeout: TimeInterval = 20
    static let mountCommandTimeout: TimeInterval = 15

    var isConnected: Bool {
        stateQueue.sync { session != nil }
    }

    var mountPath: String {
        stateQueue.sync { session?.browseURL.path ?? "" }
    }

    deinit {
        let sessionSnapshot = stateQueue.sync { session }
        guard let sessionSnapshot, sessionSnapshot.didMountShare else { return }

        do {
            try Self.unmountIfNeeded(sessionSnapshot.mountPointURL, mountRootURL: sessionSnapshot.mountRootURL)
        } catch {
            log.warning("[SMB] deferred unmount failed path='\(sessionSnapshot.mountPointURL.path)' error='\(error.localizedDescription)'")
        }
    }

    @concurrent
    func connect(host: String, port: Int, user: String, password: String, remotePath: String) async throws {
        let normalizedRemotePath = Self.normalizeRemotePath(remotePath)
        let shareRootPath = try Self.extractShareRootPath(from: normalizedRemotePath)
        let mountPointURL = try Self.existingSystemMountPointURL(shareRootPath: shareRootPath)
            ?? Self.makeMountPointURL(host: host, user: user, shareRootPath: shareRootPath)
        let browseURL = Self.makeBrowseURL(
            remotePath: normalizedRemotePath,
            shareRootPath: shareRootPath,
            mountPointURL: mountPointURL
        )

        log.debug("[SMB] connect host=\(host) port=\(port)")
        log.debug("[SMB] user=\(user) remotePath=\(normalizedRemotePath)")
        log.debug("[SMB] shareRootPath=\(shareRootPath)")
        log.debug("[SMB] mountPoint=\(mountPointURL.path)")
        log.debug("[SMB] password provided=\(!password.isEmpty)")

        try Self.createDirectoryIfNeeded(at: mountPointURL)
        let didMountShare: Bool
        if Self.isMounted(at: mountPointURL) {
            log.info("[SMB] reusing existing mount '\(mountPointURL.path)'")
            didMountShare = false
        } else {
            try Self.mountSMB(host: host, user: user, password: password, shareRootPath: shareRootPath, mountPointURL: mountPointURL)
            didMountShare = true
        }

        let newSession = SMBSession(
            host: host,
            port: port,
            user: user,
            shareRootPath: shareRootPath,
            mountRootURL: mountPointURL.deletingLastPathComponent(),
            mountPointURL: mountPointURL,
            browseURL: browseURL,
            didMountShare: didMountShare
        )

        stateQueue.sync { session = newSession }
        log.info("[SMB] connected → smb://\(user)@\(host):\(port)\(shareRootPath)")
    }

    @concurrent
    func listDirectory(_ path: String) async throws -> [RemoteFileItem] {
        let directoryURL = try resolvedURL(for: path)
        log.debug("[SMB] listDirectory path='\(path)' local='\(directoryURL.path)'")

        let resourceKeys: Set<URLResourceKey> = [
            .isDirectoryKey,
            .fileSizeKey,
            .contentModificationDateKey,
            .creationDateKey,
            .localizedTypeDescriptionKey,
            .nameKey,
        ]

        let urls = try FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: Array(resourceKeys),
            options: []
        )

        let items = try urls.map { url in
            let values = try url.resourceValues(forKeys: resourceKeys)
            let normalizedBasePath = Self.normalizeRemotePath(path)
            let itemPath = normalizedBasePath == "/" ? "/\(url.lastPathComponent)" : "\(normalizedBasePath)/\(url.lastPathComponent)"
            return RemoteFileItem(
                name: values.name ?? url.lastPathComponent,
                path: itemPath,
                isDirectory: values.isDirectory ?? false,
                size: Int64(values.fileSize ?? 0),
                modified: values.contentModificationDate,
                permissions: nil
            )
        }

        log.debug("[SMB] listed \(items.count) items at '\(path)'")
        return items
    }

    @concurrent
    func downloadFile(remotePath: String) async throws -> URL {
        let tempDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let destinationURL = tempDirectoryURL.appendingPathComponent(URL(fileURLWithPath: remotePath).lastPathComponent)
        try await downloadToLocal(remotePath: remotePath, localPath: destinationURL.path, recursive: false)
        return destinationURL
    }

    @concurrent
    func downloadToLocal(remotePath: String, localPath: String, recursive: Bool) async throws {
        let sourceURL = try resolvedURL(for: remotePath)
        let destinationURL = URL(fileURLWithPath: localPath)
        let fileManager = FileManager.default

        log.debug("[SMB] downloadToLocal from='\(sourceURL.path)' to='\(destinationURL.path)' recursive=\(recursive)")

        try Self.createParentDirectoryIfNeeded(for: destinationURL)
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        try fileManager.copyItem(at: sourceURL, to: destinationURL)
        log.info("[SMB] downloaded '\(remotePath)' → '\(destinationURL.path)'")
    }

    @concurrent
    func uploadToRemote(localPath: String, remotePath: String, recursive: Bool) async throws {
        let sourceURL = URL(fileURLWithPath: localPath)
        let destinationURL = try resolvedURL(for: remotePath)
        let fileManager = FileManager.default

        log.debug("[SMB] uploadToRemote from='\(sourceURL.path)' to='\(destinationURL.path)' recursive=\(recursive)")

        guard recursive || !Self.isDirectory(at: sourceURL) else {
            throw SMBProviderError.unsupportedRecursiveUpload(localPath)
        }

        try Self.createParentDirectoryIfNeeded(for: destinationURL)
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        try fileManager.copyItem(at: sourceURL, to: destinationURL)
        log.info("[SMB] uploaded '\(localPath)' → '\(remotePath)'")
    }

    @concurrent
    func createDirectory(at remotePath: String) async throws {
        let directoryURL = try resolvedURL(for: remotePath)
        log.debug("[SMB] createDirectory path='\(directoryURL.path)'")
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        log.info("[SMB] created directory '\(remotePath)'")
    }

    @concurrent
    func deleteItem(at remotePath: String, recursive: Bool) async throws {
        let itemURL = try resolvedURL(for: remotePath)
        let fileManager = FileManager.default

        log.debug("[SMB] deleteItem path='\(itemURL.path)' recursive=\(recursive)")

        try fileManager.removeItem(at: itemURL)
        log.info("[SMB] removed '\(remotePath)'")
    }

    @concurrent
    func disconnect() async {
        let activeSession = stateQueue.sync { () -> SMBSession? in
            let snapshot = session
            session = nil
            return snapshot
        }

        guard let activeSession else { return }

        guard activeSession.didMountShare else {
            log.info("[SMB] disconnected host=\(activeSession.host) reused mount='\(activeSession.mountPointURL.path)'")
            return
        }

        do {
            try Self.unmountIfNeeded(activeSession.mountPointURL, mountRootURL: activeSession.mountRootURL)
            log.info("[SMB] disconnected host=\(activeSession.host) mount='\(activeSession.mountPointURL.path)'")
        } catch {
            log.warning("[SMB] disconnect failed host=\(activeSession.host) error='\(error.localizedDescription)'")
        }
    }

    // MARK: - Helpers

    private func resolvedURL(for remotePath: String) throws -> URL {
        guard let currentSession = stateQueue.sync(execute: { session }) else {
            throw SMBProviderError.missingSession
        }

        let normalizedPath = Self.normalizeRemotePath(remotePath)
        let relativePath = Self.relativePathInsideShare(from: normalizedPath, shareRootPath: currentSession.shareRootPath)
        return currentSession.mountPointURL.appendingPathComponent(relativePath, isDirectory: false)
    }

    private static func normalizeRemotePath(_ path: String) -> String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "/" }
        return trimmed.hasPrefix("/") ? trimmed : "/\(trimmed)"
    }

    private static func extractShareRootPath(from remotePath: String) throws -> String {
        let normalizedPath = normalizeRemotePath(remotePath)
        let components = normalizedPath.split(separator: "/", omittingEmptySubsequences: true)

        guard let share = components.first, !share.isEmpty else {
            log.info("[SMB] connect deferred: missing share name in remotePath='\(remotePath)'")
            throw SMBProviderError.invalidRemotePath(remotePath)
        }

        return "/\(share)"
    }

    private static func relativePathInsideShare(from remotePath: String, shareRootPath: String) -> String {
        let normalizedRemotePath = normalizeRemotePath(remotePath)
        guard normalizedRemotePath != shareRootPath else { return "" }
        guard normalizedRemotePath.hasPrefix(shareRootPath + "/") else {
            return String(normalizedRemotePath.dropFirst())
        }
        return String(normalizedRemotePath.dropFirst(shareRootPath.count + 1))
    }

    private static func makeBrowseURL(remotePath: String, shareRootPath: String, mountPointURL: URL) -> URL {
        let relativePath = relativePathInsideShare(from: remotePath, shareRootPath: shareRootPath)
        guard !relativePath.isEmpty else { return mountPointURL }
        return mountPointURL.appendingPathComponent(relativePath, isDirectory: true)
    }

    private static func makeMountPointURL(host: String, user: String, shareRootPath: String) throws -> URL {
        let shareName = shareRootPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !shareName.isEmpty else { throw SMBProviderError.invalidMountURL }
        let decodedShareName = shareName.removingPercentEncoding ?? shareName
        let mountRootURL = try appMountRootURL()
        let mountName = sanitizeMountName("\(host)-\(user)-\(decodedShareName)")
        return mountRootURL.appendingPathComponent(mountName, isDirectory: true)
    }

    private static func createDirectoryIfNeeded(at url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    private static func createParentDirectoryIfNeeded(for url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    }

    private static func isDirectory(at url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        return isDirectory.boolValue
    }

    private static func mountSMB(host: String, user: String, password: String, shareRootPath: String, mountPointURL: URL) throws {
        let shareName = shareRootPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let escapedUser = percentEncodedUserInfo(user)
        let escapedPassword = percentEncodedUserInfo(password)
        let escapedHost = percentEncodedHost(host)
        let smbURL = "//\(escapedUser):\(escapedPassword)@\(escapedHost)/\(shareName)"

        let result = try runCommand(
            executable: "/sbin/mount_smbfs",
            arguments: [smbURL, mountPointURL.path],
            redactedArguments: ["//\(user):***@\(host)/\(shareName)", mountPointURL.path],
            timeout: mountCommandTimeout
        )

        if result.exitCode == 64,
           result.combinedOutput.localizedCaseInsensitiveContains("file exists"),
           isMounted(at: mountPointURL)
        {
            log.info("[SMB] mount_smbfs reported existing mount, reusing '\(mountPointURL.path)'")
            return
        }

        guard result.exitCode == 0 else {
            throw SMBProviderError.mountFailed(result.combinedOutput)
        }
    }

    private static func unmountIfNeeded(_ mountPointURL: URL, mountRootURL: URL) throws {
        guard FileManager.default.fileExists(atPath: mountPointURL.path) else { return }
        let result = try runCommand(
            executable: "/sbin/umount",
            arguments: [mountPointURL.path],
            redactedArguments: [mountPointURL.path],
            ignoreNonZeroExitCode: true
        )
        if result.exitCode == 0 {
            log.debug("[SMB] unmounted '\(mountPointURL.path)'")
            removeAppMountDirectoryIfEmpty(mountPointURL, mountRootURL: mountRootURL)
            return
        }
        if result.combinedOutput.localizedCaseInsensitiveContains("not currently mounted") {
            removeAppMountDirectoryIfEmpty(mountPointURL, mountRootURL: mountRootURL)
            return
        }
        log.warning("[SMB] umount returned exit=\(result.exitCode) path='\(mountPointURL.path)' output='\(result.combinedOutput)'")
    }

    private static func isMounted(at mountPointURL: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: mountPointURL.path) else { return false }

        let result = try? runCommand(
            executable: "/sbin/mount",
            arguments: [],
            redactedArguments: [],
            ignoreNonZeroExitCode: true
        )

        guard let output = result?.stdout, !output.isEmpty else { return false }
        return output.contains(" on \(mountPointURL.path) (smbfs")
    }

    private static func existingSystemMountPointURL(shareRootPath: String) throws -> URL? {
        let shareName = shareRootPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !shareName.isEmpty else { return nil }
        let decodedShareName = shareName.removingPercentEncoding ?? shareName
        let systemMountURL = URL(fileURLWithPath: "/Volumes", isDirectory: true)
            .appendingPathComponent(decodedShareName, isDirectory: true)
        return isMounted(at: systemMountURL) ? systemMountURL : nil
    }

    private static func appMountRootURL() throws -> URL {
        let supportURL = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return supportURL
            .appendingPathComponent("MiMiNavigator", isDirectory: true)
            .appendingPathComponent("Mounts", isDirectory: true)
    }
}
