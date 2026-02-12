// ArchiveRepacker.swift
// MiMiNavigator
//
// Extracted from ArchiveManager.swift on 12.02.2026
// Copyright © 2026 Senatov. All rights reserved.
// Description: Archive repacking — ZIP, TAR family, 7z with attribute preservation

import Foundation

// MARK: - Archive Repacker
/// Handles repacking modified archive contents back into the original archive format
enum ArchiveRepacker {

    // MARK: - Main Entry Point

    static func repack(session: ArchiveSession) async throws {
        let archiveURL = session.archiveURL
        let tempDir = session.tempDirectory

        log.info("[Repacker] Repacking \(archiveURL.lastPathComponent) from \(tempDir.path)")

        // Create backup
        let backupURL = archiveURL.deletingPathExtension()
            .appendingPathExtension("backup_\(Int(Date().timeIntervalSince1970))")
            .appendingPathExtension(archiveURL.pathExtension)
        try? FileManager.default.copyItem(at: archiveURL, to: backupURL)

        // Remove original
        try FileManager.default.removeItem(at: archiveURL)

        // List files in temp directory
        let contents = try FileManager.default.contentsOfDirectory(
            at: tempDir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )

        // Repack
        switch session.format {
        case .zip:
            try await repackZip(files: contents, to: archiveURL, workDir: tempDir)
        case .tar, .tarGz, .tarBz2, .tarXz, .tarLzma, .tarZst, .tarLz4, .tarLzo, .tarLz, .compressZ:
            try await repackTar(files: contents, to: archiveURL, format: session.format, workDir: tempDir)
        case .sevenZip, .sevenZipGeneric:
            try await repack7z(files: contents, to: archiveURL, workDir: tempDir)
        }

        // Restore original attributes
        var attrs: [FileAttributeKey: Any] = [:]
        attrs[.posixPermissions] = NSNumber(value: session.originalPosixPermissions)
        if let modDate = session.originalModificationDate {
            attrs[.modificationDate] = modDate
        }
        try? FileManager.default.setAttributes(attrs, ofItemAtPath: archiveURL.path)

        // Remove backup on success
        try? FileManager.default.removeItem(at: backupURL)
        log.info("[Repacker] Successfully repacked: \(archiveURL.lastPathComponent)")
    }

    // MARK: - ZIP

    private static func repackZip(files: [URL], to archiveURL: URL, workDir: URL) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.currentDirectoryURL = workDir
        var args = ["-r", archiveURL.path]
        args.append(contentsOf: files.map { $0.lastPathComponent })
        process.arguments = args
        process.standardOutput = Pipe()
        let errorPipe = Pipe()
        process.standardError = errorPipe
        try await ArchiveProcessRunner.run(process, errorPipe: errorPipe)
    }

    // MARK: - TAR family

    private static func repackTar(files: [URL], to archiveURL: URL, format: ArchiveFormat, workDir: URL) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        process.currentDirectoryURL = workDir
        var args = ["-c"]
        switch format {
        case .tarGz:     args.append("-z")
        case .tarBz2:    args.append("-j")
        case .tarXz:     args.append("-J")
        case .compressZ: args.append("-Z")
        case .tarLzma, .tarZst, .tarLz4, .tarLzo, .tarLz:
            break
        default: break
        }
        args.append(contentsOf: ["-f", archiveURL.path])
        args.append(contentsOf: files.map { $0.lastPathComponent })
        process.arguments = args
        process.standardOutput = Pipe()
        let errorPipe = Pipe()
        process.standardError = errorPipe

        do {
            try await ArchiveProcessRunner.run(process, errorPipe: errorPipe)
        } catch {
            log.warning("[Repacker] tar repack failed, trying 7z: \(error.localizedDescription)")
            try await repack7z(files: files, to: archiveURL, workDir: workDir)
        }
    }

    // MARK: - 7z

    private static func repack7z(files: [URL], to archiveURL: URL, workDir: URL) async throws {
        let szPath = try ArchiveToolLocator.find7z()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: szPath)
        process.currentDirectoryURL = workDir
        var args = ["a", archiveURL.path]
        args.append(contentsOf: files.map { $0.lastPathComponent })
        process.arguments = args
        process.standardOutput = Pipe()
        let errorPipe = Pipe()
        process.standardError = errorPipe
        try await ArchiveProcessRunner.run(process, errorPipe: errorPipe)
    }
}
