//
//  FTPFileProvider.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 28.03.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import FileModelKit
import Foundation

// MARK: - FTPFileProvider
final class FTPFileProvider: RemoteFileProvider, @unchecked Sendable {

    private(set) var isConnected = false
    private(set) var mountPath = ""
    private var baseURL: URL?
    private var ftpUser: String = ""
    private var ftpPassword: String = ""

    private func requireBaseURL(function: String = #function) throws -> URL {
        guard let baseURL else {
            log.warning("[FTP] \(function) failed: not connected")
            throw RemoteProviderError.notConnected
        }
        return baseURL
    }

    private func ftpURL(for remotePath: String, isDirectory: Bool = false) throws -> URL {
        let base = try requireBaseURL()
        let normalizedPath = normalizeRemotePath(remotePath)
        let finalPath = isDirectory && !normalizedPath.hasSuffix("/") ? normalizedPath + "/" : normalizedPath

        var comps = URLComponents(url: base, resolvingAgainstBaseURL: false)
        comps?.path = finalPath
        comps?.user = ftpUser
        comps?.password = ftpPassword

        guard let url = comps?.url else {
            throw RemoteProviderError.invalidURL
        }
        return url
    }

    private func normalizeRemotePath(_ path: String) -> String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "/" }
        return trimmed.hasPrefix("/") ? trimmed : "/\(trimmed)"
    }

    private func appendRemoteComponent(_ name: String, to remotePath: String) -> String {
        let basePath = normalizeRemotePath(remotePath)
        return basePath == "/" ? "/\(name)" : basePath + "/\(name)"
    }

    private func ensureLocalPathExists(_ localURL: URL) throws -> Bool {
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

    private static func buildMountPath(
        scheme: String, user: String,
        host: String, port: Int,
        remotePath: String
    ) -> String {
        let portStr = (scheme == "sftp" && port == 22) || (scheme == "ftp" && port == 21) ? "" : ":\(port)"
        let path = remotePath.isEmpty ? "" : remotePath.hasPrefix("/") ? remotePath : "/\(remotePath)"
        return "\(scheme)://\(user)@\(host)\(portStr)\(path)"
    }

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
        mountPath = Self.buildMountPath(
            scheme: "ftp", user: user, host: host,
            port: port, remotePath: remotePath)
        isConnected = true
        log.info("[FTP] connected → \(mountPath)")
    }

    // MARK: - List Directory (curl — URLSession FTP is deprecated on macOS)
    @concurrent func listDirectory(_ path: String) async throws -> [RemoteFileItem] {
        guard let base = baseURL else { throw RemoteProviderError.notConnected }
        guard !path.contains("://") else {
            log.error("[FTP] rejecting mangled path='\(path)'")
            throw RemoteProviderError.invalidURL
        }
        let dirPath = path.hasPrefix("/") ? path : "/\(path)"
        let listPath = dirPath.hasSuffix("/") ? dirPath : dirPath + "/"
        var comps = URLComponents(url: base, resolvingAgainstBaseURL: false)
        comps?.path = listPath
        comps?.user = ftpUser
        comps?.password = ftpPassword
        guard let dirURL = comps?.url else { throw RemoteProviderError.invalidURL }
        let raw = try await curlFTPList(url: dirURL)
        let items = parseFTPListing(raw, basePath: path)
        log.debug("[FTP] listed \(items.count) items at \(path)")
        return items
    }

    @concurrent private func curlFTPList(url: URL) async throws -> String {
        let scheme = url.scheme ?? ""
        guard scheme == "ftp" || scheme == "ftps",
            let host = url.host, !host.isEmpty
        else { throw RemoteProviderError.invalidURL }
        let urlStr = url.absoluteString
        return try await withCheckedThrowingContinuation { cont in
            DispatchQueue.global(qos: .userInitiated)
                .async {
                    let proc = Process()
                    proc.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
                    proc.arguments = ["-s", "--max-time", "15", urlStr]
                    let out = Pipe()
                    let err = Pipe()
                    proc.standardOutput = out
                    proc.standardError = err
                    do { try proc.run() } catch {
                        log.error("[FTP] curl failed to start: \(error.localizedDescription)")
                        cont.resume(throwing: RemoteProviderError.listingFailed)
                        return
                    }
                    proc.waitUntilExit()
                    let raw =
                        String(
                            data: out.fileHandleForReading.readDataToEndOfFile(),
                            encoding: .utf8) ?? ""
                    if proc.terminationStatus != 0 {
                        let e =
                            String(
                                data: err.fileHandleForReading.readDataToEndOfFile(),
                                encoding: .utf8) ?? ""
                        log.warning("[FTP] curl exit=\(proc.terminationStatus): \(e.prefix(200))")
                    }
                    cont.resume(returning: raw)
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

    // MARK: - Download File (FTP via curl)
    @concurrent func downloadFile(remotePath: String) async throws -> URL {
        guard let base = baseURL else { throw RemoteProviderError.notConnected }
        let fileName = (remotePath as NSString).lastPathComponent
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MiMiFTP", isDirectory: true)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        let localURL = tmpDir.appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: localURL.path) {
            try? FileManager.default.removeItem(at: localURL)
        }
        var comps = URLComponents(url: base, resolvingAgainstBaseURL: false)
        comps?.path = remotePath.hasPrefix("/") ? remotePath : "/\(remotePath)"
        comps?.user = ftpUser
        comps?.password = ftpPassword
        guard let fileURL = comps?.url else { throw RemoteProviderError.invalidURL }
        log.info("[FTP] downloading '\(remotePath)' → '\(localURL.path)'")
        try await curlDownload(url: fileURL, to: localURL)
        let size = (try? FileManager.default.attributesOfItem(atPath: localURL.path)[.size] as? Int64) ?? 0
        log.info("[FTP] download OK size=\(size) → '\(localURL.lastPathComponent)'")
        return localURL
    }

    // MARK: - Download to Local (FTP — file only, no recursive)
    @concurrent func downloadToLocal(remotePath: String, localPath: String, recursive: Bool) async throws {
        guard let base = baseURL else { throw RemoteProviderError.notConnected }
        if recursive {
            log.warning("[FTP] recursive download not supported via FTP — use SFTP")
            throw RemoteProviderError.downloadFailed("Recursive FTP download not supported")
        }
        var comps = URLComponents(url: base, resolvingAgainstBaseURL: false)
        comps?.path = remotePath.hasPrefix("/") ? remotePath : "/\(remotePath)"
        comps?.user = ftpUser
        comps?.password = ftpPassword
        guard let fileURL = comps?.url else { throw RemoteProviderError.invalidURL }
        let localURL = URL(fileURLWithPath: localPath)
        try await curlDownload(url: fileURL, to: localURL)
    }

    @concurrent func uploadToRemote(localPath: String, remotePath: String, recursive: Bool) async throws {
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

    @concurrent func createDirectory(at remotePath: String) async throws {
        let normalizedRemotePath = normalizeRemotePath(remotePath)
        log.info("[FTP] mkdir '\(normalizedRemotePath)'")
        try await curlFTPCommand(path: normalizedRemotePath, commands: ["MKD \(normalizedRemotePath)"])
    }

    @concurrent func deleteItem(at remotePath: String, recursive: Bool) async throws {
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

    private func uploadDirectory(from localURL: URL, to remotePath: String) async throws {
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

    private func curlUploadFile(from localURL: URL, to remotePath: String) async throws {
        let remoteURL = try ftpURL(for: remotePath, isDirectory: false)
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
                proc.arguments = [
                    "-sS",
                    "--ftp-create-dirs",
                    "--max-time", "300",
                    "-T", localURL.path,
                    remoteURL.absoluteString,
                ]
                let errPipe = Pipe()
                proc.standardError = errPipe
                do {
                    try proc.run()
                    proc.waitUntilExit()
                    if proc.terminationStatus != 0 {
                        let errText = String(
                            data: errPipe.fileHandleForReading.readDataToEndOfFile(),
                            encoding: .utf8
                        ) ?? ""
                        log.warning("[FTP] upload exit=\(proc.terminationStatus): \(errText.prefix(200))")
                        cont.resume(throwing: RemoteProviderError.downloadFailed("curl upload: \(errText.prefix(200))"))
                    } else {
                        cont.resume()
                    }
                } catch {
                    cont.resume(throwing: error)
                }
            }
        }
    }

    private func curlFTPCommand(path: String, commands: [String]) async throws {
        let targetURL = try ftpURL(for: path, isDirectory: false)
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: "/usr/bin/curl")

                var args: [String] = ["-sS", "--max-time", "60"]
                for command in commands {
                    args.append("--quote")
                    args.append(command)
                }
                args.append(targetURL.absoluteString)
                proc.arguments = args

                let errPipe = Pipe()
                proc.standardError = errPipe
                do {
                    try proc.run()
                    proc.waitUntilExit()
                    if proc.terminationStatus != 0 {
                        let errText = String(
                            data: errPipe.fileHandleForReading.readDataToEndOfFile(),
                            encoding: .utf8
                        ) ?? ""
                        log.warning("[FTP] command exit=\(proc.terminationStatus): \(errText.prefix(200))")
                        cont.resume(throwing: RemoteProviderError.downloadFailed("curl quote: \(errText.prefix(200))"))
                    } else {
                        cont.resume()
                    }
                } catch {
                    cont.resume(throwing: error)
                }
            }
        }
    }

    private func curlDownload(url: URL, to localURL: URL) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .userInitiated)
                .async {
                    let proc = Process()
                    proc.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
                    proc.arguments = [
                        "-s", "--max-time", "300",
                        "-o", localURL.path, url.absoluteString,
                    ]
                    let errPipe = Pipe()
                    proc.standardError = errPipe
                    do {
                        try proc.run()
                        proc.waitUntilExit()
                        if proc.terminationStatus != 0 {
                            let e =
                                String(
                                    data: errPipe.fileHandleForReading.readDataToEndOfFile(),
                                    encoding: .utf8) ?? ""
                            cont.resume(throwing: RemoteProviderError.downloadFailed("curl: \(e.prefix(200))"))
                        } else {
                            cont.resume()
                        }
                    } catch {
                        cont.resume(throwing: error)
                    }
                }
        }
    }

    private func parseFTPListing(_ raw: String, basePath: String) -> [RemoteFileItem] {
        raw.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .compactMap { line -> RemoteFileItem? in
                let parts = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                guard parts.count >= 9 else { return nil }
                let name = parts[8...].joined(separator: " ")
                guard name != "." && name != ".." else { return nil }
                let isDir = parts[0].hasPrefix("d")
                let size = Int64(parts[4]) ?? 0
                let path = basePath.hasSuffix("/") ? "\(basePath)\(name)" : "\(basePath)/\(name)"
                return RemoteFileItem(
                    name: name, path: path, isDirectory: isDir,
                    size: size, permissions: parts[0])
            }
    }
}
