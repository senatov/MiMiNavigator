//
//  FTPFileProvider+Paths.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 29.03.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import Foundation

extension FTPFileProvider {

    // MARK: - Base URL

    func requireBaseURL(function: String = #function) throws -> URL {
        guard let baseURL else {
            log.warning("[FTP] \(function) failed: not connected")
            throw RemoteProviderError.notConnected
        }
        return baseURL
    }

    // MARK: - Remote URL construction

    func ftpURL(for remotePath: String, isDirectory: Bool = false) throws -> URL {
        let base = try requireBaseURL()
        let normalizedPath = normalizeRemotePath(remotePath)
        let finalPath = isDirectory && !normalizedPath.hasSuffix("/") ? normalizedPath + "/" : normalizedPath

        var components = URLComponents(url: base, resolvingAgainstBaseURL: false)
        components?.path = finalPath
        components?.user = ftpUser
        components?.password = ftpPassword

        guard let url = components?.url else {
            throw RemoteProviderError.invalidURL
        }
        return url
    }

    func remoteFileURL(for remotePath: String) throws -> URL {
        try ftpURL(for: remotePath, isDirectory: false)
    }

    // MARK: - Path normalization

    func normalizedConnectPath(_ remotePath: String) -> String {
        remotePath.hasPrefix("/") ? remotePath : "/\(remotePath)"
    }

    func normalizedDirectoryPath(_ path: String) -> String {
        let directoryPath = path.hasPrefix("/") ? path : "/\(path)"
        return directoryPath.hasSuffix("/") ? directoryPath : directoryPath + "/"
    }

    func normalizeRemotePath(_ path: String) -> String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "/" }
        return trimmed.hasPrefix("/") ? trimmed : "/\(trimmed)"
    }

    func appendRemoteComponent(_ name: String, to remotePath: String) -> String {
        let basePath = normalizeRemotePath(remotePath)
        return basePath == "/" ? "/\(name)" : basePath + "/\(name)"
    }

    // MARK: - Local path checks

    func ensureLocalPathExists(_ localURL: URL) throws -> Bool {
        var isDirectory: ObjCBool = false

        guard FileManager.default.fileExists(atPath: localURL.path, isDirectory: &isDirectory) else {
            throw NSError(
                domain: "FTPFileProvider",
                code: 2001,
                userInfo: [NSLocalizedDescriptionKey: "Local path does not exist: \(localURL.path)"]
            )
        }

        return isDirectory.boolValue
    }

    func makeTemporaryDownloadURL(for remotePath: String) throws -> URL {
        let fileName = (remotePath as NSString).lastPathComponent
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MiMiFTP", isDirectory: true)

        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )

        let localURL = temporaryDirectory.appendingPathComponent(fileName)

        if FileManager.default.fileExists(atPath: localURL.path) {
            try? FileManager.default.removeItem(at: localURL)
        }

        return localURL
    }

    // MARK: - Mount path

    static func buildMountPath(
        scheme: String,
        user: String,
        host: String,
        port: Int,
        remotePath: String
    ) -> String {
        let portString = ((scheme == "sftp" && port == 22) || (scheme == "ftp" && port == 21))
            ? ""
            : ":\(port)"

        let path: String
        if remotePath.isEmpty {
            path = ""
        } else if remotePath.hasPrefix("/") {
            path = remotePath
        } else {
            path = "/\(remotePath)"
        }

        return "\(scheme)://\(user)@\(host)\(portString)\(path)"
    }
}
