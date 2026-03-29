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

        try ensureParentDirectoryExists(for: localURL)
        try removeExistingFileIfNeeded(at: localURL)

        let data = try await readRemoteFileData(
            at: normalizedRemotePath,
            using: sftp
        )

        try data.write(to: localURL, options: .atomic)
        log.info("[SFTP] saved file '\(normalizedRemotePath)' → '\(localURL.path)' bytes=\(data.count)")
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
                let data = try await readRemoteFileData(at: childRemotePath, using: sftp)
                try ensureParentDirectoryExists(for: childLocalURL)
                try removeExistingFileIfNeeded(at: childLocalURL)
                try data.write(to: childLocalURL, options: Data.WritingOptions.atomic)
                log.info("[SFTP] saved nested file '\(childRemotePath)' → '\(childLocalURL.path)' bytes=\(data.count)")
            }
        }
    }

    private func readRemoteFileData(at remotePath: String, using sftp: SFTPClient) async throws -> Data {
        let handle = try await sftp.openFile(filePath: remotePath, flags: .read)

        do {
            var offset: UInt64 = 0
            var collected = Data()
            let chunkSize = 256 * 1024

            while true {
                var chunk = try await handle.read(from: offset, length: UInt32(chunkSize))
                let readableBytes = chunk.readableBytes
                if readableBytes == 0 {
                    break
                }

                if let bytes = chunk.readBytes(length: readableBytes) {
                    collected.append(contentsOf: bytes)
                }
                offset += UInt64(readableBytes)
            }

            try await handle.close()
            return collected
        } catch {
            try? await handle.close()
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

        let localURL = temporaryDirectory.appendingPathComponent(fileName)
        try removeExistingFileIfNeeded(at: localURL)
        return localURL
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

    private func removeExistingFileIfNeeded(at url: URL) throws {
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
}
