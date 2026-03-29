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

        let target = url.absoluteString

        return try await runCurlCaptureOutput(
            arguments: [
                "-sS",
                "--disable-epsv",
                "--connect-timeout", "12",
                "--max-time", "35",
                target,
            ],
            failure: { status, errorText in
                log.warning("[FTP] LIST failed url='\(target)' exit=\(status)")
                log.warning("[FTP] LIST stderr=\(errorText.prefix(200))")
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

    private func parseFTPModifiedDate(month: String, day: String, yearOrTime: String) -> Date? {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())

        let formatterWithYear = DateFormatter()
        formatterWithYear.locale = Locale(identifier: "en_US_POSIX")
        formatterWithYear.timeZone = TimeZone.current
        formatterWithYear.dateFormat = "MMM d yyyy"

        let formatterWithTime = DateFormatter()
        formatterWithTime.locale = Locale(identifier: "en_US_POSIX")
        formatterWithTime.timeZone = TimeZone.current
        formatterWithTime.dateFormat = "MMM d yyyy HH:mm"

        if yearOrTime.contains(":") {
            let candidate = "\(month) \(day) \(currentYear) \(yearOrTime)"
            if let parsed = formatterWithTime.date(from: candidate) {
                if parsed > Date(),
                   let adjusted = calendar.date(byAdding: .year, value: -1, to: parsed) {
                    return adjusted
                }
                return parsed
            }
            return nil
        }

        let candidate = "\(month) \(day) \(yearOrTime)"
        return formatterWithYear.date(from: candidate)
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

                let permissions = parts[0]
                let isDirectory = permissions.hasPrefix("d")
                let size = Int64(parts[4]) ?? 0
                let month = parts[5]
                let day = parts[6]
                let yearOrTime = parts[7]
                let modified = parseFTPModifiedDate(month: month, day: day, yearOrTime: yearOrTime)

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
                    modified: modified,
                    permissions: permissions
                )
            }
    }
}
