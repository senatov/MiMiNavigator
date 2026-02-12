// ArchiveExtractor.swift
// MiMiNavigator
//
// Extracted from ArchiveManager.swift on 12.02.2026
// Copyright © 2026 Senatov. All rights reserved.
// Description: Archive extraction — ZIP, TAR family, 7z with auto-fallback

import Foundation

// MARK: - Archive Extractor
/// Handles extraction of archives to temp directories
enum ArchiveExtractor {

    // MARK: - Main Entry Point

    static func extract(archiveURL: URL, format: ArchiveFormat, to destination: URL) async throws {
        log.info("[Extractor] Extracting \(archiveURL.lastPathComponent) (format: \(format.displayName)) → \(destination.path)")

        switch format {
        case .zip:
            try await extractZip(archiveURL: archiveURL, to: destination)
        case .tar, .tarGz, .tarBz2, .tarXz, .tarLzma, .tarZst, .tarLz4, .tarLzo, .tarLz, .compressZ:
            try await extractTar(archiveURL: archiveURL, format: format, to: destination)
        case .sevenZip, .sevenZipGeneric:
            try await extract7z(archiveURL: archiveURL, to: destination)
        }

        log.info("[Extractor] Extraction complete: \(archiveURL.lastPathComponent)")
    }

    // MARK: - ZIP

    static func extractZip(archiveURL: URL, to destination: URL) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-o", archiveURL.path, "-d", destination.path]
        process.standardOutput = Pipe()
        let errorPipe = Pipe()
        process.standardError = errorPipe
        try await ArchiveProcessRunner.run(process, errorPipe: errorPipe)
    }

    // MARK: - TAR family

    static func extractTar(archiveURL: URL, format: ArchiveFormat, to destination: URL) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        var args = ["-x"]
        switch format {
        case .tarGz:     args.append("-z")
        case .tarBz2:    args.append("-j")
        case .tarXz:     args.append("-J")
        case .compressZ: args.append("-Z")
        // lzma, zst, lz4, lzo, lz — macOS tar auto-detects via libarchive
        case .tarLzma, .tarZst, .tarLz4, .tarLzo, .tarLz:
            break
        default: break
        }
        args.append(contentsOf: ["-f", archiveURL.path, "-C", destination.path])
        process.arguments = args
        process.standardOutput = Pipe()
        let errorPipe = Pipe()
        process.standardError = errorPipe

        do {
            try await ArchiveProcessRunner.run(process, errorPipe: errorPipe)
        } catch {
            // Fallback to 7z if tar fails
            log.warning("[Extractor] tar failed for \(archiveURL.lastPathComponent), trying 7z fallback")
            try await extract7z(archiveURL: archiveURL, to: destination)
        }
    }

    // MARK: - 7z

    static func extract7z(archiveURL: URL, to destination: URL) async throws {
        let szPath = try ArchiveToolLocator.find7z()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: szPath)
        process.arguments = ["x", archiveURL.path, "-o\(destination.path)", "-y"]
        process.standardOutput = Pipe()
        let errorPipe = Pipe()
        process.standardError = errorPipe
        try await ArchiveProcessRunner.run(process, errorPipe: errorPipe)
    }
}

// MARK: - Tool Locator
/// Finds CLI tools on the system
enum ArchiveToolLocator {
    static func find7z() throws -> String {
        let paths = ["/opt/homebrew/bin/7z", "/usr/local/bin/7z", "/usr/bin/7z"]
        guard let szPath = paths.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            throw ArchiveManagerError.toolNotFound("7z not installed. Install with: brew install p7zip")
        }
        return szPath
    }
}

// MARK: - Process Runner
/// Async wrapper for running CLI processes
enum ArchiveProcessRunner {
    static func run(_ process: Process, errorPipe: Pipe) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            process.terminationHandler = { proc in
                if proc.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorMessage = String(data: errorData, encoding: .utf8) ?? "Exit code \(proc.terminationStatus)"
                    continuation.resume(throwing: ArchiveManagerError.extractionFailed(errorMessage))
                }
            }
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
