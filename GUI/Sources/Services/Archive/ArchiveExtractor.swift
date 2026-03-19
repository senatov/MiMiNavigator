// ArchiveExtractor.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 12.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Archive extraction — ZIP, TAR family, 7z with progress callbacks

import Foundation

// MARK: - Archive Extractor
enum ArchiveExtractor {

    /// Progress callback: receives each extracted filename
    typealias ProgressLine = @Sendable (String) -> Void

    @concurrent static func extract(
        archiveURL: URL,
        format: ArchiveFormat,
        to destination: URL,
        password: String? = nil,
        onProgress: ProgressLine? = nil
    ) async throws {
        switch format {
        case .zip:
            try await extractZip(archiveURL: archiveURL, to: destination, password: password, onProgress: onProgress)
        case .tar, .tarGz, .tarBz2, .tarXz, .tarLzma, .tarZst, .tarLz4, .tarLzo, .tarLz, .compressZ:
            try await extractTar(archiveURL: archiveURL, format: format, to: destination, password: password, onProgress: onProgress)
        case .sevenZip, .sevenZipGeneric:
            try await extract7z(archiveURL: archiveURL, to: destination, password: password, onProgress: onProgress)
        }
        log.info("[Extractor] Done: \(archiveURL.lastPathComponent)")
    }

    // MARK: - ZIP

    @concurrent private static func extractZip(
        archiveURL: URL, to destination: URL,
        password: String? = nil, onProgress: ProgressLine? = nil
    ) async throws {
        let errPipe = Pipe()
        let outPipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        var args = ["-o", "-DD"]  // no -q: we want verbose output for progress
        if let pwd = password, !pwd.isEmpty { args += ["-P", pwd] }
        args += [archiveURL.path, "-d", destination.path]
        process.arguments = args
        process.standardOutput = outPipe
        process.standardError = errPipe
        process.standardInput = FileHandle(forReadingAtPath: "/dev/null")

        try await ArchiveProcessRunner.runWithProgress(
            process, errorPipe: errPipe, outputPipe: outPipe, onLine: onProgress
        )
    }

    // MARK: - TAR family

    @concurrent private static func extractTar(
        archiveURL: URL, format: ArchiveFormat, to destination: URL,
        password: String? = nil, onProgress: ProgressLine? = nil
    ) async throws {
        let errPipe = Pipe()
        let outPipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        var args = ["-xv"]  // verbose — outputs each extracted file
        switch format {
        case .tarGz:     args.append("-z")
        case .tarBz2:    args.append("-j")
        case .tarXz:     args.append("-J")
        case .compressZ: args.append("-Z")
        default:         break
        }
        args += ["-f", archiveURL.path, "-C", destination.path]
        process.arguments = args
        process.standardOutput = outPipe
        process.standardError = errPipe
        process.standardInput = FileHandle(forReadingAtPath: "/dev/null")

        do {
            try await ArchiveProcessRunner.runWithProgress(
                process, errorPipe: errPipe, outputPipe: outPipe, onLine: onProgress
            )
        } catch {
            log.warning("[Extractor] tar failed for \(archiveURL.lastPathComponent), trying 7z: \(error)")
            try await extract7z(archiveURL: archiveURL, to: destination, password: password, onProgress: onProgress)
        }
    }

    // MARK: - 7z

    @concurrent private static func extract7z(
        archiveURL: URL, to destination: URL,
        password: String? = nil, onProgress: ProgressLine? = nil
    ) async throws {
        let errPipe = Pipe()
        let outPipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: try ArchiveToolLocator.find7z())
        var args = ["x", archiveURL.path, "-o\(destination.path)", "-y", "-bb1"]  // -bb1 = show extracted files
        if let pwd = password, !pwd.isEmpty { args.append("-p\(pwd)") }
        process.arguments = args
        process.standardOutput = outPipe
        process.standardError = errPipe
        process.standardInput = FileHandle(forReadingAtPath: "/dev/null")

        try await ArchiveProcessRunner.runWithProgress(
            process, errorPipe: errPipe, outputPipe: outPipe, onLine: onProgress
        )
    }
}
