//
//  SFTPFileProvider+Upload.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 29.03.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import Citadel
import Foundation
import NIOCore

extension SFTPFileProvider {

    private func childNameForRecursiveDelete(from entry: SFTPMessage.Name) -> String? {
        guard let component = entry.components.first else { return nil }

        let name = component.filename
        guard name != ".", name != ".." else { return nil }
        return name
    }

    // MARK: - Upload / mkdir / delete

    @concurrent
    func uploadToRemote(localPath: String, remotePath: String, recursive: Bool) async throws {
        let localURL = URL(fileURLWithPath: localPath)
        let normalizedRemotePath = normalizeUploadRemotePath(remotePath)

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: localURL.path, isDirectory: &isDirectory) else {
            throw RemoteProviderError.downloadFailed("Local path not found: \(localURL.path)")
        }

        if isDirectory.boolValue {
            guard recursive else {
                throw RemoteProviderError.downloadFailed("Directory upload requires recursive=true")
            }

            log.info("[SFTP] recursive upload '\(localURL.path)' → '\(normalizedRemotePath)'")
            try await uploadDirectory(from: localURL, to: normalizedRemotePath)
            return
        }

        log.info("[SFTP] upload '\(localURL.path)' → '\(normalizedRemotePath)'")
        try await uploadRegularFile(from: localURL, to: normalizedRemotePath)
    }

    @concurrent
    func createDirectory(at remotePath: String) async throws {
        let sftp = try requireSFTPClient()
        let normalizedRemotePath = normalizeUploadRemotePath(remotePath)

        do {
            try await sftp.createDirectory(atPath: normalizedRemotePath)
            log.info("[SFTP] mkdir '\(normalizedRemotePath)'")
        } catch {
            let message = error.localizedDescription.lowercased()
            if message.contains("file exists") || message.contains("failure") {
                log.debug("[SFTP] mkdir ignored for '\(normalizedRemotePath)': \(error.localizedDescription)")
                return
            }
            throw error
        }
    }

    @concurrent
    func deleteItem(at remotePath: String, recursive: Bool) async throws {
        let sftp = try requireSFTPClient()
        let normalizedRemotePath = normalizeUploadRemotePath(remotePath)

        let directoryEntries = try? await sftp.listDirectory(atPath: normalizedRemotePath)
        let isDirectory = directoryEntries != nil

        if isDirectory {
            if recursive, let entries = directoryEntries {
                for entry in entries {
                    guard let name = childNameForRecursiveDelete(from: entry) else { continue }
                    let childPath = appendUploadRemoteComponent(name, to: normalizedRemotePath)
                    try await deleteItem(at: childPath, recursive: true)
                }
            }

            try await sftp.remove(at: normalizedRemotePath)
            log.info("[SFTP] rmdir '\(normalizedRemotePath)'")
            return
        }

        try await sftp.remove(at: normalizedRemotePath)
        log.info("[SFTP] delete file '\(normalizedRemotePath)'")
    }

    // MARK: - Upload helpers

    private func normalizeUploadRemotePath(_ path: String) -> String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return remoteRootPath }
        return trimmed.hasPrefix("/") ? trimmed : "/\(trimmed)"
    }

    private func appendUploadRemoteComponent(_ name: String, to remotePath: String) -> String {
        let base = normalizeUploadRemotePath(remotePath)
        return base == "/" ? "/\(name)" : base + "/\(name)"
    }

    private func uploadRegularFile(from localURL: URL, to remotePath: String) async throws {
        let sftp = try requireSFTPClient()
        let normalizedRemotePath = normalizeUploadRemotePath(remotePath)

        try await ensureRemoteParentDirectoryExists(for: normalizedRemotePath)

        let data = try localFileData(at: localURL)
        let allocator = ByteBufferAllocator()
        let handle = try await sftp.openFile(
            filePath: normalizedRemotePath,
            flags: [.write, .create, .truncate]
        )

        do {
            var offset: UInt64 = 0
            let chunkSize = 256 * 1024

            while offset < UInt64(data.count) {
                let remaining = data.count - Int(offset)
                let length = min(chunkSize, remaining)
                let chunk = data.subdata(in: Int(offset)..<Int(offset) + length)
                var buffer = allocator.buffer(capacity: chunk.count)
                buffer.writeBytes(chunk)
                try await handle.write(buffer, at: offset)
                offset += UInt64(length)
            }

            try await handle.close()
        } catch {
            try? await handle.close()
            throw error
        }
    }

    private func uploadDirectory(from localURL: URL, to remotePath: String) async throws {
        let normalizedRemotePath = normalizeUploadRemotePath(remotePath)
        try await createDirectory(at: normalizedRemotePath)

        let childURLs = try FileManager.default.contentsOfDirectory(
            at: localURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        )

        for childURL in childURLs {
            let childName = childURL.lastPathComponent
            let childRemotePath = appendUploadRemoteComponent(childName, to: normalizedRemotePath)
            let values = try childURL.resourceValues(forKeys: [.isDirectoryKey])

            if values.isDirectory == true {
                try await uploadDirectory(from: childURL, to: childRemotePath)
            } else {
                try await uploadRegularFile(from: childURL, to: childRemotePath)
            }
        }
    }

    private func ensureRemoteParentDirectoryExists(for remotePath: String) async throws {
        let normalizedRemotePath = normalizeUploadRemotePath(remotePath)
        let parentPath = (normalizedRemotePath as NSString).deletingLastPathComponent
        let normalizedParent = parentPath.isEmpty ? "/" : parentPath

        guard normalizedParent != "/" else { return }

        var currentPath = ""
        for component in normalizedParent.split(separator: "/") {
            currentPath += "/\(component)"
            try await createDirectory(at: currentPath)
        }
    }

    private func localFileData(at url: URL) throws -> Data {
        try Data(contentsOf: url)
    }
}
