//
//  SFTPFileProvider+Download.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 29.03.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//


import Citadel
import Foundation

extension SFTPFileProvider {

    // MARK: - Download

    @concurrent
    func downloadFile(remotePath: String) async throws -> URL {
        let normalizedRemotePath = normalizedDownloadRemotePath(remotePath)
        let temporaryURL = try makeTemporaryDownloadURL(for: normalizedRemotePath)

        try await downloadToLocal(
            remotePath: normalizedRemotePath,
            localPath: temporaryURL.path,
            recursive: false
        )

        let downloadedSize = localFileSize(at: temporaryURL)
        log.info("[SFTP] downloaded '\(normalizedRemotePath)' → '\(temporaryURL.path)' size=\(downloadedSize)")
        return temporaryURL
    }

    @concurrent
    func downloadToLocal(remotePath: String, localPath: String, recursive: Bool) async throws {
        let normalizedRemotePath = normalizedDownloadRemotePath(remotePath)
        let localURL = URL(fileURLWithPath: localPath)
        let sftp = try requireSFTPClient()

        let isDirectory = (try? await sftp.listDirectory(atPath: normalizedRemotePath)) != nil

        if isDirectory {
            guard recursive else {
                throw RemoteProviderError.downloadFailed("Directory download requires recursive=true")
            }

            try await downloadDirectory(
                at: normalizedRemotePath,
                to: localURL,
                using: sftp
            )
            return
        }

        try await downloadRegularFile(at: normalizedRemotePath, to: localURL, using: sftp)
    }

    // MARK: - Download helpers

    private func normalizedDownloadRemotePath(_ path: String) -> String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return remoteRootPath }
        return trimmed.hasPrefix("/") ? trimmed : "/\(trimmed)"
    }

    private func downloadDirectory(at remotePath: String, to localURL: URL, using sftp: SFTPClient) async throws {
        try FileManager.default.createDirectory(
            at: localURL,
            withIntermediateDirectories: true
        )

        let entries = try await sftp.listDirectory(atPath: remotePath)

        for entry in entries {
            guard let component = entry.components.first else { continue }
            let name = component.filename
            guard name != ".", name != ".." else { continue }

            let childRemotePath = appendDownloadRemoteComponent(name, to: remotePath)
            let childLocalURL = localURL.appendingPathComponent(name)
            let isDirectory = component.longname.hasPrefix("d")

            if isDirectory {
                try await downloadDirectory(at: childRemotePath, to: childLocalURL, using: sftp)
            } else {
                try await downloadRegularFile(at: childRemotePath, to: childLocalURL, using: sftp)
            }
        }
    }

    // MARK: - Bounded File Download
    private func downloadRegularFile(at remotePath: String, to localURL: URL, using sftp: SFTPClient) async throws {
        try ensureParentDirectoryExists(for: localURL)
        let temporaryURL = localURL.deletingLastPathComponent().appendingPathComponent(".mimi-download-\(UUID().uuidString)")
        FileManager.default.createFile(atPath: temporaryURL.path, contents: nil)
        let output = try FileHandle(forWritingTo: temporaryURL)
        let handle = try await sftp.openFile(filePath: remotePath, flags: .read)
        do {
            let size = try await handle.readAttributes().size
            var offset: UInt64 = 0
            while size.map({ offset < $0 }) ?? true {
                try Task.checkCancellation()
                let length = UInt32(min(UInt64(256 * 1024), (size ?? (offset + 256 * 1024)) - offset))
                var buffer = try await handle.read(from: offset, length: length)
                guard let bytes = buffer.readBytes(length: buffer.readableBytes), !bytes.isEmpty else {
                    if size != nil { throw RemoteProviderError.downloadFailed("Unexpected end of remote file: \(remotePath)") }
                    break
                }
                try output.write(contentsOf: bytes)
                offset += UInt64(bytes.count)
            }
            try await handle.close()
            try output.close()
            try Task.checkCancellation()
            if FileManager.default.fileExists(atPath: localURL.path) {
                _ = try FileManager.default.replaceItemAt(localURL, withItemAt: temporaryURL)
            } else {
                try FileManager.default.moveItem(at: temporaryURL, to: localURL)
            }
            log.info("[SFTP] saved file '\(remotePath)' → '\(localURL.path)' bytes=\(offset)")
        } catch {
            try? await handle.close()
            try? output.close()
            try? FileManager.default.removeItem(at: temporaryURL)
            throw error
        }
    }

    private func appendDownloadRemoteComponent(_ name: String, to remotePath: String) -> String {
        let base = normalizedDownloadRemotePath(remotePath)
        return base == "/" ? "/\(name)" : base + "/\(name)"
    }

    private func makeTemporaryDownloadURL(for remotePath: String) throws -> URL {
        let fileName = (remotePath as NSString).lastPathComponent
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MiMiSFTP", isDirectory: true)

        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )

        let downloadDirectory = temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: downloadDirectory, withIntermediateDirectories: true)
        return downloadDirectory.appendingPathComponent(fileName)
    }

    private func localFileSize(at url: URL) -> Int64 {
        (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
    }

    private func ensureParentDirectoryExists(for url: URL) throws {
        let parent = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: parent,
            withIntermediateDirectories: true
        )
    }

}
