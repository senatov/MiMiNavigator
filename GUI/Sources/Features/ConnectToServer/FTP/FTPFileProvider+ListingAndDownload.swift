//
//  FTPFileProvider+ListingAndDownload.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 29.03.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import FileModelKit
import Foundation

extension FTPFileProvider {

    func curlFTPList(url: URL) async throws -> String {
        let scheme = url.scheme ?? ""
        guard scheme == "ftp" || scheme == "ftps",
            let host = url.host,
            !host.isEmpty
        else {
            throw RemoteProviderError.invalidURL
        }

        return try await runCurlCaptureOutput(
            arguments: ["-s", "--max-time", "15", url.absoluteString],
            failure: { status, errorText in
                log.warning("[FTP] curl exit=\(status): \(errorText.prefix(200))")
                return RemoteProviderError.listingFailed
            }
        )
    }

    // MARK: - Download

    @concurrent
    func downloadFile(remotePath: String) async throws -> URL {
        let localURL = try makeTemporaryDownloadURL(for: remotePath)
        let remoteURL = try remoteFileURL(for: remotePath)

        log.info("[FTP] downloading '\(remotePath)' → '\(localURL.path)'")
        try await curlDownload(url: remoteURL, to: localURL)

        let fileSize = (try? FileManager.default.attributesOfItem(atPath: localURL.path)[.size] as? Int64) ?? 0
        log.info("[FTP] download OK size=\(fileSize) → '\(localURL.lastPathComponent)'")

        return localURL
    }

    @concurrent
    func downloadToLocal(remotePath: String, localPath: String, recursive: Bool) async throws {
        guard !recursive else {
            log.warning("[FTP] recursive download not supported via FTP — use SFTP")
            throw RemoteProviderError.downloadFailed("Recursive FTP download not supported")
        }

        let remoteURL = try remoteFileURL(for: remotePath)
        let localURL = URL(fileURLWithPath: localPath)

        try await curlDownload(url: remoteURL, to: localURL)
    }

    func curlDownload(url: URL, to localURL: URL) async throws {
        try await runCurlVoid(
            arguments: [
                "-s",
                "--max-time", "300",
                "-o", localURL.path,
                url.absoluteString,
            ],
            failure: { _, errorText in
                RemoteProviderError.downloadFailed("curl: \(errorText.prefix(200))")
            }
        )
    }

    // MARK: - Listing parser

    func parseFTPListing(_ raw: String, basePath: String) -> [RemoteFileItem] {
        raw
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .compactMap { line in
                let parts = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                guard parts.count >= 9 else { return nil }

                let name = parts[8...].joined(separator: " ")
                guard name != "." && name != ".." else { return nil }

                let isDirectory = parts[0].hasPrefix("d")
                let size = Int64(parts[4]) ?? 0

                let path: String
                if basePath.hasSuffix("/") {
                    path = "\(basePath)\(name)"
                } else {
                    path = "\(basePath)/\(name)"
                }

                return RemoteFileItem(
                    name: name,
                    path: path,
                    isDirectory: isDirectory,
                    size: size,
                    permissions: parts[0]
                )
            }
    }
}
