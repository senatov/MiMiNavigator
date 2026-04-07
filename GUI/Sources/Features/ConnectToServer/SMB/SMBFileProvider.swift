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


final class SMBFileProvider: @unchecked Sendable, RemoteFileProvider {
    private enum SMBProviderError: LocalizedError {
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
                    return "Invalid SMB remote path: \(path)"
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
        let mountPointURL: URL
    }

    private let stateQueue = DispatchQueue(label: "MiMiNavigator.SMBFileProvider.state")
    private var session: SMBSession?

    var isConnected: Bool {
        stateQueue.sync { session != nil }
    }

    var mountPath: String {
        stateQueue.sync { session?.mountPointURL.path ?? "" }
    }

    deinit {
        let mountPointURL = stateQueue.sync { session?.mountPointURL }
        guard let mountPointURL else { return }

        do {
            try Self.unmountIfNeeded(mountPointURL)
        } catch {
            log.warning("[SMB] deferred unmount failed path='\(mountPointURL.path)' error='\(error.localizedDescription)'")
        }
    }

    @concurrent
    func connect(host: String, port: Int, user: String, password: String, remotePath: String) async throws {
        let normalizedRemotePath = Self.normalizeRemotePath(remotePath)
        let shareRootPath = try Self.extractShareRootPath(from: normalizedRemotePath)
        let mountPointURL = try Self.makeMountPointURL(host: host, user: user, shareRootPath: shareRootPath)

        log.debug("[SMB] connect host=\(host) port=\(port)")
        log.debug("[SMB] user=\(user) remotePath=\(normalizedRemotePath)")
        log.debug("[SMB] shareRootPath=\(shareRootPath)")
        log.debug("[SMB] mountPoint=\(mountPointURL.path)")
        log.debug("[SMB] password provided=\(!password.isEmpty)")

        try Self.createDirectoryIfNeeded(at: mountPointURL)
        try Self.unmountIfNeeded(mountPointURL)
        try Self.mountSMB(host: host, user: user, password: password, shareRootPath: shareRootPath, mountPointURL: mountPointURL)

        let newSession = SMBSession(
            host: host,
            port: port,
            user: user,
            shareRootPath: shareRootPath,
            mountPointURL: mountPointURL
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

        do {
            try Self.unmountIfNeeded(activeSession.mountPointURL)
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

    private static func makeMountPointURL(host: String, user: String, shareRootPath: String) throws -> URL {
        let shareName = shareRootPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !shareName.isEmpty else { throw SMBProviderError.invalidMountURL }

        let baseURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".mimi", isDirectory: true)
            .appendingPathComponent("remote", isDirectory: true)
            .appendingPathComponent("smb-mounts", isDirectory: true)

        let safeHost = host.replacingOccurrences(of: "/", with: "_")
        let safeUser = user.replacingOccurrences(of: "/", with: "_")
        let safeShare = shareName.replacingOccurrences(of: "/", with: "_")

        return baseURL.appendingPathComponent("\(safeHost)__\(safeUser)__\(safeShare)", isDirectory: true)
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
        let escapedUser = user.addingPercentEncoding(withAllowedCharacters: .urlUserAllowed) ?? user
        let escapedPassword = password.addingPercentEncoding(withAllowedCharacters: .urlPasswordAllowed) ?? password
        let escapedHost = host.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? host
        let smbURL = "//\(escapedUser):\(escapedPassword)@\(escapedHost)/\(shareName)"

        let result = try runCommand(
            executable: "/sbin/mount_smbfs",
            arguments: [smbURL, mountPointURL.path],
            redactedArguments: ["//\(user):***@\(host)/\(shareName)", mountPointURL.path]
        )

        guard result.exitCode == 0 else {
            throw SMBProviderError.mountFailed(result.combinedOutput)
        }
    }

    private static func unmountIfNeeded(_ mountPointURL: URL) throws {
        guard FileManager.default.fileExists(atPath: mountPointURL.path) else { return }

        let result = try runCommand(
            executable: "/sbin/umount",
            arguments: [mountPointURL.path],
            redactedArguments: [mountPointURL.path],
            ignoreNonZeroExitCode: true
        )

        if result.exitCode == 0 {
            log.debug("[SMB] unmounted '\(mountPointURL.path)'")
            return
        }

        if result.combinedOutput.localizedCaseInsensitiveContains("not currently mounted") {
            return
        }

        log.warning("[SMB] umount returned exit=\(result.exitCode) path='\(mountPointURL.path)' output='\(result.combinedOutput)'")
    }

    private struct CommandResult {
        let exitCode: Int32
        let stdout: String
        let stderr: String

        var combinedOutput: String {
            let parts = [
                stdout.trimmingCharacters(in: .whitespacesAndNewlines), stderr.trimmingCharacters(in: .whitespacesAndNewlines),
            ]
            .filter { !$0.isEmpty }
            return parts.joined(separator: " | ")
        }
    }

    @discardableResult
    private static func runCommand(
        executable: String,
        arguments: [String],
        redactedArguments: [String],
        ignoreNonZeroExitCode: Bool = false
    ) throws -> CommandResult {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        log.debug("[SMB] run \(executable) args=\(redactedArguments.joined(separator: " "))")

        try process.run()
        process.waitUntilExit()

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""
        let result = CommandResult(exitCode: process.terminationStatus, stdout: stdout, stderr: stderr)

        if !ignoreNonZeroExitCode, result.exitCode != 0 {
            log.warning("[SMB] command failed exit=\(result.exitCode) output='\(result.combinedOutput)'")
            throw SMBProviderError.commandFailed(result.combinedOutput)
        }

        return result
    }
}
