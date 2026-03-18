// ArchiveService.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 22.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: High-level archive creation API — delegates packing to Repacker internals

import Foundation

// MARK: - Archive Service
/// Creates new archives from selected files. Delegates to CLI tools via ArchiveProcessRunner.
@MainActor
final class ArchiveService {

    static let shared = ArchiveService()
    private init() {}

    // MARK: - Create Archive

    /// Creates an archive from given files in the specified destination directory.
    func createArchive(
        from files: [URL],
        to destination: URL,
        archiveName: String,
        format: ArchiveFormat,
        compressionLevel: CompressionLevel = .normal,
        password: String? = nil
    ) async throws -> URL {
        guard !files.isEmpty else {
            throw ArchiveManagerError.repackFailed("No files provided")
        }
        let archiveURL = destination.appendingPathComponent("\(archiveName).\(format.fileExtension)")
        guard !FileManager.default.fileExists(atPath: archiveURL.path) else {
            throw FileOperationError.fileAlreadyExists(archiveURL.lastPathComponent)
        }
        let workDir = files[0].deletingLastPathComponent()
        try await pack(files: files, to: archiveURL, format: format, workDir: workDir, compressionLevel: compressionLevel, password: password)
        log.info("[ArchiveService] Created: \(archiveURL.lastPathComponent) level=\(compressionLevel)")
        return archiveURL
    }

    // MARK: - Private

    private func pack(files: [URL], to archiveURL: URL, format: ArchiveFormat, workDir: URL, compressionLevel: CompressionLevel = .normal, password: String? = nil) async throws {
        let names = files.map(\.lastPathComponent)
        let errorPipe = Pipe()
        let process = Process()
        process.currentDirectoryURL = workDir
        
        let level = compressionLevel.rawValue

        switch format {
        case .zip:
            process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
            var args = ["-\(level)", "-r"]
            if let pwd = password, !pwd.isEmpty {
                args += ["-e", "-P", pwd]
            }
            args += [archiveURL.path] + names
            process.arguments = args

        case .tar:
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            process.arguments = ["-c", "-f", archiveURL.path] + names

        case .tarGz:
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            // GZIP level via env var
            process.environment = ["GZIP": "-\(level)"]
            process.arguments = ["-c", "-z", "-f", archiveURL.path] + names

        case .tarBz2:
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            process.environment = ["BZIP2": "-\(level)"]
            process.arguments = ["-c", "-j", "-f", archiveURL.path] + names

        case .tarXz:
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            process.environment = ["XZ_OPT": "-\(level)"]
            process.arguments = ["-c", "-J", "-f", archiveURL.path] + names

        case .tarLzma, .tarZst, .tarLz4, .tarLzo, .tarLz, .compressZ:
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            process.arguments = ["-c", "-f", archiveURL.path] + names

        case .sevenZip, .sevenZipGeneric:
            process.executableURL = URL(fileURLWithPath: try ArchiveToolLocator.find7z())
            var args = ["a", "-mx=\(level)"]
            if let pwd = password, !pwd.isEmpty {
                args.append("-p\(pwd)")
            }
            args += [archiveURL.path] + names
            process.arguments = args
        }

        process.standardOutput = Pipe()
        process.standardError = errorPipe
        try await ArchiveProcessRunner.run(process, errorPipe: errorPipe)
    }
}
