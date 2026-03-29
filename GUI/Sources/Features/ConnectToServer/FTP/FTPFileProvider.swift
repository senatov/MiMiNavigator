//
//  FTPFileProvider.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 28.03.2025.
//  Copyright © 2026 Senatov. All rights reserved.
//

import FileModelKit
import Foundation

// MARK: - FTPFileProvider
final class FTPFileProvider: RemoteFileProvider, @unchecked Sendable {

    // MARK: - State

    private(set) var isConnected = false
    private(set) var mountPath = ""

    var baseURL: URL?
    var ftpUser = ""
    var ftpPassword = ""

    // MARK: - State reset

    private func resetConnectionState() {
        isConnected = false
        baseURL = nil
        ftpUser = ""
        ftpPassword = ""
        mountPath = ""
    }

    private func makeBaseURL(host: String, port: Int, remotePath: String) throws -> URL {
        var components = URLComponents()
        let normalizedPath = normalizedConnectPath(remotePath)

        components.scheme = "ftp"
        components.host = host
        components.port = port != 21 ? port : nil
        components.path = normalizedPath

        guard let url = components.url else {
            throw RemoteProviderError.invalidURL
        }

        return url
    }

    @concurrent
    func connect(host: String, port: Int, user: String, password: String, remotePath: String) async throws {
        let url = try makeBaseURL(host: host, port: port, remotePath: remotePath)

        baseURL = url
        ftpUser = user
        ftpPassword = password

        let initialPath = remotePath.isEmpty ? "/" : remotePath
        _ = try await listDirectory(initialPath)

        mountPath = Self.buildMountPath(
            scheme: "ftp",
            user: user,
            host: host,
            port: port,
            remotePath: remotePath
        )
        isConnected = true

        log.info("[FTP] connected → \(mountPath)")
    }

    @concurrent
    func disconnect() async {
        resetConnectionState()
        log.info("[FTP] disconnected")
    }

    private func makeDirectoryURL(for path: String) throws -> URL {
        guard let base = baseURL else {
            throw RemoteProviderError.notConnected
        }

        guard !path.contains("://") else {
            log.error("[FTP] rejecting mangled path='\(path)'")
            throw RemoteProviderError.invalidURL
        }

        let directoryPath = normalizedDirectoryPath(path)

        var components = URLComponents(url: base, resolvingAgainstBaseURL: false)
        components?.path = directoryPath
        components?.user = ftpUser
        components?.password = ftpPassword

        guard let directoryURL = components?.url else {
            throw RemoteProviderError.invalidURL
        }

        return directoryURL
    }

    @concurrent
    func listDirectory(_ path: String) async throws -> [RemoteFileItem] {
        let directoryURL = try makeDirectoryURL(for: path)

        let rawListing = try await curlFTPList(url: directoryURL)
        let items = parseFTPListing(rawListing, basePath: path)

        log.debug("[FTP] listed \(items.count) items at \(path)")
        return items
    }

    // MARK: - Curl execution

    func runCurlVoid(
        arguments: [String],
        failure: @Sendable @escaping (_ status: Int32, _ errorText: String) -> Error
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
                process.arguments = arguments

                let errorPipe = Pipe()
                process.standardError = errorPipe

                do {
                    try process.run()
                    process.waitUntilExit()

                    if process.terminationStatus == 0 {
                        continuation.resume()
                        return
                    }

                    let errorText = String(
                        data: errorPipe.fileHandleForReading.readDataToEndOfFile(),
                        encoding: .utf8
                    ) ?? ""

                    continuation.resume(throwing: failure(process.terminationStatus, errorText))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func runCurlCaptureOutput(
        arguments: [String],
        failure: @Sendable @escaping (_ status: Int32, _ errorText: String) -> Error
    ) async throws -> String {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
                process.arguments = arguments

                let outputPipe = Pipe()
                let errorPipe = Pipe()
                process.standardOutput = outputPipe
                process.standardError = errorPipe

                do {
                    try process.run()
                    process.waitUntilExit()

                    let outputText = String(
                        data: outputPipe.fileHandleForReading.readDataToEndOfFile(),
                        encoding: .utf8
                    ) ?? ""

                    if process.terminationStatus == 0 {
                        continuation.resume(returning: outputText)
                        return
                    }

                    let errorText = String(
                        data: errorPipe.fileHandleForReading.readDataToEndOfFile(),
                        encoding: .utf8
                    ) ?? ""

                    continuation.resume(throwing: failure(process.terminationStatus, errorText))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

}
