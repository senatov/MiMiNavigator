// ArchiveExtractor.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 12.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Archive extraction — ZIP, TAR family, 7z with auto-fallback

import Foundation

// MARK: - Archive Extractor
enum ArchiveExtractor {

    @concurrent static func extract(archiveURL: URL, format: ArchiveFormat, to destination: URL) async throws {
        switch format {
        case .zip:
            try await extractZip(archiveURL: archiveURL, to: destination)
        case .tar, .tarGz, .tarBz2, .tarXz, .tarLzma, .tarZst, .tarLz4, .tarLzo, .tarLz, .compressZ:
            try await extractTar(archiveURL: archiveURL, format: format, to: destination)
        case .sevenZip, .sevenZipGeneric:
            try await extract7z(archiveURL: archiveURL, to: destination)
        }
        log.info("[Extractor] Done: \(archiveURL.lastPathComponent)")
    }

    // MARK: - ZIP

    @concurrent private static func extractZip(archiveURL: URL, to destination: URL) async throws {
        let pipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        // -o overwrite, -q quiet, -DD skip timestamps (avoids fchmod errors in /tmp)
        process.arguments = ["-o", "-q", "-DD", archiveURL.path, "-d", destination.path]
        process.standardOutput = Pipe()
        process.standardError = pipe
        process.standardInput = FileHandle(forReadingAtPath: "/dev/null")
        try await ArchiveProcessRunner.run(process, errorPipe: pipe)
    }

    // MARK: - TAR family

    @concurrent private static func extractTar(archiveURL: URL, format: ArchiveFormat, to destination: URL) async throws {
        let pipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        var args = ["-x"]
        switch format {
        case .tarGz:     args.append("-z")
        case .tarBz2:    args.append("-j")
        case .tarXz:     args.append("-J")
        case .compressZ: args.append("-Z")
        default:         break   // lzma/zst/lz4/lzo/lz — libarchive auto-detects
        }
        args += ["-f", archiveURL.path, "-C", destination.path]
        process.arguments = args
        process.standardOutput = Pipe()
        process.standardError = pipe
        process.standardInput = FileHandle(forReadingAtPath: "/dev/null")
        do {
            try await ArchiveProcessRunner.run(process, errorPipe: pipe)
        } catch {
            log.warning("[Extractor] tar failed for \(archiveURL.lastPathComponent), trying 7z")
            try await extract7z(archiveURL: archiveURL, to: destination)
        }
    }

    // MARK: - 7z

    @concurrent private static func extract7z(archiveURL: URL, to destination: URL) async throws {
        let pipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: try ArchiveToolLocator.find7z())
        process.arguments = ["x", archiveURL.path, "-o\(destination.path)", "-y"]
        process.standardOutput = Pipe()
        process.standardError = pipe
        process.standardInput = FileHandle(forReadingAtPath: "/dev/null")
        try await ArchiveProcessRunner.run(process, errorPipe: pipe)
    }
}
