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
        log.warning("[FTP] upload not supported yet local='\(localPath)' remote='\(remotePath)' recursive=\(recursive)")
        throw RemoteProviderError.notImplemented
    }

    @concurrent func createDirectory(at remotePath: String) async throws {
        log.warning("[FTP] mkdir not supported yet path='\(remotePath)'")
        throw RemoteProviderError.notImplemented
    }

    @concurrent func deleteItem(at remotePath: String, recursive: Bool) async throws {
        log.warning("[FTP] delete not supported yet path='\(remotePath)' recursive=\(recursive)")
        throw RemoteProviderError.notImplemented
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
