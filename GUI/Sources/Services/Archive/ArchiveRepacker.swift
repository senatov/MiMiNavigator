// ArchiveRepacker.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 12.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Repacks modified archive contents back into original format with updated timestamps

import Foundation

// MARK: - Archive Repacker
enum ArchiveRepacker {

    // MARK: - Entry Names
    private static func archiveEntryNames(from contents: [URL], workDir: URL) -> [String] {
        contents.map { url in
            let standardizedURL = url.standardizedFileURL
            let standardizedWorkDir = workDir.standardizedFileURL

            if standardizedURL.deletingLastPathComponent() == standardizedWorkDir {
                return standardizedURL.lastPathComponent
            }

            let path = standardizedURL.path
            let workDirPath = standardizedWorkDir.path
            if path.hasPrefix(workDirPath + "/") {
                return String(path.dropFirst(workDirPath.count + 1))
            }

            return standardizedURL.lastPathComponent
        }
    }

    @concurrent static func repack(session: ArchiveSession) async throws {
        let archiveURL = session.archiveURL
        let tempDir = session.tempDirectory
        log.info("[Repacker] Repacking \(archiveURL.lastPathComponent)")

        let backupURL = archiveURL
            .deletingPathExtension()
            .appendingPathExtension("backup_\(Int(Date().timeIntervalSince1970))")
            .appendingPathExtension(archiveURL.pathExtension)
        try? FileManager.default.copyItem(at: archiveURL, to: backupURL)
        try FileManager.default.removeItem(at: archiveURL)

        let topLevel = (try? FileManager.default.contentsOfDirectory(
            at: tempDir, includingPropertiesForKeys: nil, options: .skipsHiddenFiles
        )) ?? []

        let entryNames = archiveEntryNames(from: topLevel, workDir: tempDir)

        do {
            switch session.format {
            case .zip:
                try await repackZip(entryNames: entryNames, to: archiveURL, workDir: tempDir)
            case .tar, .tarGz, .tarBz2, .tarXz, .tarLzma, .tarZst, .tarLz4, .tarLzo, .tarLz, .compressZ:
                try await repackTar(entryNames: entryNames, to: archiveURL, format: session.format, workDir: tempDir)
            case .sevenZip, .sevenZipGeneric:
                try await repack7z(entryNames: entryNames, to: archiveURL, workDir: tempDir)
            case .gzip, .bzip2, .xz, .lzma, .zstd, .lz4, .lzo, .lzip:
                throw ArchiveManagerError.repackFailed("Unsupported repack format: \(session.format.displayName)")
            }
        } catch {
            // Restore backup on failure
            try? FileManager.default.copyItem(at: backupURL, to: archiveURL)
            try? FileManager.default.removeItem(at: backupURL)
            throw error
        }

        // Set current timestamps — archive was modified
        let now = Date()
        try? FileManager.default.setAttributes([
            .posixPermissions: NSNumber(value: session.originalPosixPermissions),
            .modificationDate: now,
            .creationDate:     now,
        ], ofItemAtPath: archiveURL.path)

        try? FileManager.default.removeItem(at: backupURL)
        log.info("[Repacker] Done: \(archiveURL.lastPathComponent)")
    }

    // MARK: - ZIP

    @concurrent private static func repackZip(entryNames: [String], to archiveURL: URL, workDir: URL) async throws {
        let pipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.currentDirectoryURL = workDir
        process.arguments = ["-r", archiveURL.path] + entryNames
        process.standardOutput = Pipe()
        process.standardError = pipe
        try await ArchiveProcessRunner.run(process, errorPipe: pipe)
    }

    // MARK: - TAR family

    @concurrent private static func repackTar(entryNames: [String], to archiveURL: URL, format: ArchiveFormat, workDir: URL) async throws {
        let pipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        process.currentDirectoryURL = workDir
        var args = ["-c"]
        switch format {
        case .tarGz:     args.append("-z")
        case .tarBz2:    args.append("-j")
        case .tarXz:     args.append("-J")
        case .compressZ: args.append("-Z")
        default:         break
        }
        args += ["-f", archiveURL.path] + entryNames
        process.arguments = args
        process.standardOutput = Pipe()
        process.standardError = pipe
        do {
            try await ArchiveProcessRunner.run(process, errorPipe: pipe)
        } catch {
            log.warning("[Repacker] tar failed, retrying with 7z")
            try await repack7z(entryNames: entryNames, to: archiveURL, workDir: workDir)
        }
    }

    // MARK: - 7z

    @concurrent private static func repack7z(entryNames: [String], to archiveURL: URL, workDir: URL) async throws {
        let pipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: try ArchiveToolLocator.find7z())
        process.currentDirectoryURL = workDir
        process.arguments = ["a", archiveURL.path] + entryNames
        process.standardOutput = Pipe()
        process.standardError = pipe
        try await ArchiveProcessRunner.run(process, errorPipe: pipe)
    }
}
