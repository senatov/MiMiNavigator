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
        format: ArchiveFormat
    ) async throws -> URL {
        guard !files.isEmpty else {
            throw ArchiveManagerError.repackFailed("No files provided")
        }
        let archiveURL = destination.appendingPathComponent("\(archiveName).\(format.fileExtension)")
        guard !FileManager.default.fileExists(atPath: archiveURL.path) else {
            throw FileOperationError.fileAlreadyExists(archiveURL.lastPathComponent)
        }
        let workDir = files[0].deletingLastPathComponent()
        try await pack(files: files, to: archiveURL, format: format, workDir: workDir)
        log.info("[ArchiveService] Created: \(archiveURL.lastPathComponent)")
        return archiveURL
    }

    /// Creates an archive with progress reporting (progress is approximate).
    func createArchive(
        from files: [URL],
        to archiveURL: URL,
        format: ArchiveFormat,
        progressHandler: @escaping (Double) -> Void
    ) async throws {
        guard !files.isEmpty else {
            throw ArchiveManagerError.repackFailed("No files provided")
        }
        progressHandler(0.0)
        let workDir = files[0].deletingLastPathComponent()
        try await pack(files: files, to: archiveURL, format: format, workDir: workDir)
        progressHandler(1.0)
        log.info("[ArchiveService] Created: \(archiveURL.lastPathComponent)")
    }

    // MARK: - Private

    private func pack(files: [URL], to archiveURL: URL, format: ArchiveFormat, workDir: URL) async throws {
        let names = files.map(\.lastPathComponent)
        let errorPipe = Pipe()
        let process = Process()
        process.currentDirectoryURL = workDir

        switch format {
        case .zip:
            process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
            process.arguments = ["-r", archiveURL.path] + names

        case .tar:
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            process.arguments = ["-c", "-f", archiveURL.path] + names

        case .tarGz:
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            process.arguments = ["-c", "-z", "-f", archiveURL.path] + names

        case .tarBz2:
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            process.arguments = ["-c", "-j", "-f", archiveURL.path] + names

        case .tarXz:
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            process.arguments = ["-c", "-J", "-f", archiveURL.path] + names

        case .tarLzma, .tarZst, .tarLz4, .tarLzo, .tarLz, .compressZ:
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            process.arguments = ["-c", "-f", archiveURL.path] + names

        case .sevenZip, .sevenZipGeneric:
            process.executableURL = URL(fileURLWithPath: try ArchiveToolLocator.find7z())
            process.arguments = ["a", archiveURL.path] + names
        }

        process.standardOutput = Pipe()
        process.standardError = errorPipe
        try await ArchiveProcessRunner.run(process, errorPipe: errorPipe)
    }
}
