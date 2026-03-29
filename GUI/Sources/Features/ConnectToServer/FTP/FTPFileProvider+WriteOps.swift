//
//  FTPFileProvider+WriteOps.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 29.03.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import Foundation

extension FTPFileProvider {

    // MARK: - Write operations

    @concurrent
    func uploadToRemote(localPath: String, remotePath: String, recursive: Bool) async throws {
        let localURL = URL(fileURLWithPath: localPath)
        let isDirectory = try ensureLocalPathExists(localURL)
        let normalizedRemotePath = normalizeRemotePath(remotePath)

        if isDirectory {
            guard recursive else {
                throw NSError(
                    domain: "FTPFileProvider",
                    code: 2002,
                    userInfo: [NSLocalizedDescriptionKey: "Directory upload requires recursive=true"]
                )
            }

            log.info("[FTP] recursive upload '\(localPath)' → '\(normalizedRemotePath)'")
            try await uploadDirectory(from: localURL, to: normalizedRemotePath)
            return
        }

        log.info("[FTP] upload '\(localPath)' → '\(normalizedRemotePath)'")
        try await curlUploadFile(from: localURL, to: normalizedRemotePath)
    }

    @concurrent
    func createDirectory(at remotePath: String) async throws {
        let normalizedRemotePath = normalizeRemotePath(remotePath)
        log.info("[FTP] mkdir '\(normalizedRemotePath)'")
        try await curlFTPCommand(path: normalizedRemotePath, commands: ["MKD \(normalizedRemotePath)"])
    }

    @concurrent
    func deleteItem(at remotePath: String, recursive: Bool) async throws {
        let normalizedRemotePath = normalizeRemotePath(remotePath)

        if recursive {
            do {
                let children = try await listDirectory(normalizedRemotePath)
                for child in children {
                    try await deleteItem(at: child.path, recursive: true)
                }

                log.info("[FTP] rmdir '\(normalizedRemotePath)'")
                try await curlFTPCommand(path: normalizedRemotePath, commands: ["RMD \(normalizedRemotePath)"])
                return
            } catch {
                log.debug("[FTP] recursive delete fallback to file delete for '\(normalizedRemotePath)': \(error.localizedDescription)")
            }
        }

        log.info("[FTP] delete file '\(normalizedRemotePath)'")
        try await curlFTPCommand(path: normalizedRemotePath, commands: ["DELE \(normalizedRemotePath)"])
    }

    // MARK: - Upload helpers

    func uploadDirectory(from localURL: URL, to remotePath: String) async throws {
        let normalizedRemotePath = normalizeRemotePath(remotePath)

        do {
            try await createDirectory(at: normalizedRemotePath)
        } catch {
            log.debug("[FTP] mkdir preflight ignored for '\(normalizedRemotePath)': \(error.localizedDescription)")
        }

        let childURLs = try FileManager.default.contentsOfDirectory(
            at: localURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        )

        for childURL in childURLs {
            let childName = childURL.lastPathComponent
            let childRemotePath = appendRemoteComponent(childName, to: normalizedRemotePath)
            let values = try childURL.resourceValues(forKeys: [.isDirectoryKey])

            if values.isDirectory == true {
                try await uploadDirectory(from: childURL, to: childRemotePath)
            } else {
                try await curlUploadFile(from: childURL, to: childRemotePath)
            }
        }
    }

    func curlUploadFile(from localURL: URL, to remotePath: String) async throws {
        let remoteURL = try ftpURL(for: remotePath, isDirectory: false)
        try await runCurlVoid(
            arguments: [
                "-sS",
                "--ftp-create-dirs",
                "--max-time", "300",
                "-T", localURL.path,
                remoteURL.absoluteString,
            ],
            failure: { status, errorText in
                log.warning("[FTP] upload exit=\(status): \(errorText.prefix(200))")
                return RemoteProviderError.downloadFailed("curl upload: \(errorText.prefix(200))")
            }
        )
    }

    // MARK: - Command helpers

    func curlFTPCommand(path: String, commands: [String]) async throws {
        let targetURL = try ftpURL(for: path, isDirectory: false)

        var arguments: [String] = ["-sS", "--max-time", "60"]
        for command in commands {
            arguments.append("--quote")
            arguments.append(command)
        }
        arguments.append(targetURL.absoluteString)

        try await runCurlVoid(
            arguments: arguments,
            failure: { status, errorText in
                log.warning("[FTP] command exit=\(status): \(errorText.prefix(200))")
                return RemoteProviderError.downloadFailed("curl quote: \(errorText.prefix(200))")
            }
        )
    }
}
