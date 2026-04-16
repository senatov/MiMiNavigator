// CompressService.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 04.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Service for macOS native Compress functionality (like Finder's "Compress")

import Foundation

// MARK: - Compress Service
/// Handles macOS native compression (creates .zip archives like Finder)
final class CompressService: @unchecked Sendable {

    static let shared = CompressService()
    private let fileManager = FileManager.default

    private init() {
        log.debug("\(#function) CompressService initialized")
    }

    // MARK: - Compress Files

    /// Compresses files — uses `zip` for password protection, `ditto` otherwise
    @discardableResult
    func compress(
        files: [URL],
        archiveName: String,
        destination: URL,
        moveToArchive: Bool = false,
        compressionLevel: CompressionLevel = .normal,
        password: String? = nil,
        onStage: (@Sendable (String) -> Void)? = nil,
        onLog: (@Sendable (String) -> Void)? = nil,
        onProgress: (@Sendable (Double?) -> Void)? = nil,
        processHandle: ActiveArchiveProcess? = nil
    ) async throws -> URL {
        log.debug("\(#function) files.count=\(files.count) level=\(compressionLevel) hasPassword=\(password != nil)")
        guard !files.isEmpty else {
            log.error("\(#function) FAILED: no files to compress")
            throw CompressError.noFilesToCompress
        }

        let archiveURL = destination.appendingPathComponent(archiveName)
        log.info("\(#function) compressing \(files.count) item(s) → '\(archiveURL.path)' level=\(compressionLevel.rawValue)")
        onStage?("Preparing compression…")
        onProgress?(0.05)
        onLog?("Archive: \(archiveName)")
        onLog?("Destination: \(destination.path)")
        onLog?("Items: \(files.count)")
        onLog?("Level: \(compressionLevel.displayName)")
        onLog?("Encrypted: \((password?.isEmpty == false) ? "yes" : "no")")

        // Use zip command for password support, ditto otherwise
        if let password = password, !password.isEmpty {
            try await compressWithZip(
                files: files,
                to: archiveURL,
                compressionLevel: compressionLevel,
                password: password,
                onStage: onStage,
                onLog: onLog,
                onProgress: onProgress,
                processHandle: processHandle
            )
        } else {
            try await compressWithDitto(
                files: files,
                to: archiveURL,
                compressionLevel: compressionLevel,
                onStage: onStage,
                onLog: onLog,
                onProgress: onProgress,
                processHandle: processHandle
            )
        }

        onStage?("Finalizing archive…")
        onProgress?(0.95)
        log.info("\(#function) SUCCESS created: '\(archiveURL.path)'")

        // Move originals to trash if requested
        if moveToArchive {
            onStage?("Removing source files…")
            for file in files {
                do {
                    try fileManager.removeItem(at: file)
                    log.debug("\(#function) removed original: '\(file.path)'")
                    onLog?("Removed source: \(file.lastPathComponent)")
                } catch {
                    log.error("\(#function) FAILED to remove original: '\(file.path)' error='\(error.localizedDescription)'")
                    throw CompressError.moveToArchiveFailed(file.lastPathComponent, error.localizedDescription)
                }
            }
        }
        
        return archiveURL
    }
    
    // MARK: - Ditto Compression (no password)

    private func compressWithDitto(
        files: [URL],
        to archiveURL: URL,
        compressionLevel: CompressionLevel,
        onStage: (@Sendable (String) -> Void)?,
        onLog: (@Sendable (String) -> Void)?,
        onProgress: (@Sendable (Double?) -> Void)?,
        processHandle: ActiveArchiveProcess?
    ) async throws {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")

        var args = ["-c", "-k"]

        // Compression level: ditto uses --zlibCompressionLevel (1-9)
        if compressionLevel != .normal {
            args.append("--zlibCompressionLevel")
            args.append("\(compressionLevel.rawValue)")
        }

        var temporaryStagingURL: URL?

        if files.count == 1 {
            args.append("--keepParent")
            args.append(files[0].path)
            onLog?("Source: \(files[0].lastPathComponent)")
        } else {
            // Multiple files — stage in temp directory
            onStage?("Preparing files…")
            let stagingDirURL = fileManager.temporaryDirectory
                .appendingPathComponent(".MiMiNavigator-Compress-\(UUID().uuidString)", isDirectory: true)
            try fileManager.createDirectory(at: stagingDirURL, withIntermediateDirectories: true)
            temporaryStagingURL = stagingDirURL

            for (index, sourceURL) in files.enumerated() {
                let targetURL = stagingDirURL.appendingPathComponent(sourceURL.lastPathComponent)
                if fileManager.fileExists(atPath: targetURL.path) {
                    try fileManager.removeItem(at: targetURL)
                }
                try fileManager.copyItem(at: sourceURL, to: targetURL)
                onLog?("Staged [\(index + 1)/\(files.count)]: \(sourceURL.lastPathComponent)")
                onProgress?(0.1 + (Double(index + 1) / Double(max(files.count, 1))) * 0.35)
            }

            args.append(stagingDirURL.path)
        }

        args.append(archiveURL.path)
        task.arguments = args

        defer {
            if let temporaryStagingURL {
                try? fileManager.removeItem(at: temporaryStagingURL)
            }
        }

        log.debug("\(#function) ditto \(args.joined(separator: " "))")
        onStage?("Compressing with ditto…")
        onProgress?(nil)
        onLog?("Tool: ditto")
        onLog?("Command: ditto \(args.joined(separator: " "))")

        let pipe = Pipe()
        task.standardError = pipe
        let outputPipe = Pipe()
        task.standardOutput = outputPipe
        do {
            try await ArchiveProcessRunner.runWithProgress(
                task,
                errorPipe: pipe,
                outputPipe: outputPipe,
                onLine: { line in onLog?(line) },
                processHandle: processHandle
            )
        } catch {
            log.error("\(#function) ditto FAILED error='\(error.localizedDescription)'")
            throw CompressError.compressionFailed(error.localizedDescription)
        }
    }

    // MARK: - Zip Compression (with password)

    private func compressWithZip(
        files: [URL],
        to archiveURL: URL,
        compressionLevel: CompressionLevel,
        password: String,
        onStage: (@Sendable (String) -> Void)?,
        onLog: (@Sendable (String) -> Void)?,
        onProgress: (@Sendable (Double?) -> Void)?,
        processHandle: ActiveArchiveProcess?
    ) async throws {
        // zip -e -P password -r archive.zip files...
        // Note: -P puts password on command line (visible in ps). For production, use expect or stdin.
        // For now, using -e which prompts for password — we'll pipe it via stdin

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/zip")

        var args: [String] = []

        // Compression level: zip uses -0 to -9
        args.append("-\(compressionLevel.rawValue)")

        // Encryption with password
        args.append("-e")
        args.append("-P")
        args.append(password)

        // Recurse into directories
        args.append("-r")

        // Output archive
        args.append(archiveURL.path)

        // Input files
        for file in files {
            args.append(file.path)
        }

        task.arguments = args
        task.currentDirectoryURL = files[0].deletingLastPathComponent()

        log.debug("\(#function) zip -\(compressionLevel.rawValue) -e -P *** -r \(archiveURL.path) ...")
        onStage?("Compressing with zip…")
        onProgress?(nil)
        onLog?("Tool: zip")
        onLog?("Encrypted ZIP archive")
        onLog?("Command: zip -\(compressionLevel.rawValue) -e -P *** -r \(archiveURL.path) ...")

        let errorPipe = Pipe()
        let outputPipe = Pipe()
        task.standardError = errorPipe
        task.standardOutput = outputPipe
        do {
            try await ArchiveProcessRunner.runWithProgress(
                task,
                errorPipe: errorPipe,
                outputPipe: outputPipe,
                onLine: { line in onLog?(line) },
                processHandle: processHandle
            )
        } catch {
            log.error("\(#function) zip FAILED error='\(error.localizedDescription)'")
            throw CompressError.compressionFailed(error.localizedDescription)
        }
    }
}

// MARK: - Compress Errors

enum CompressError: LocalizedError {
    case noFilesToCompress
    case compressionFailed(String)
    case moveToArchiveFailed(String, String)

    var errorDescription: String? {
        switch self {
        case .noFilesToCompress:
            return "No files selected for compression"
        case .compressionFailed(let message):
            return "Compression failed: \(message)"
        case .moveToArchiveFailed(let fileName, let message):
            return "Archive created, but failed to remove '\(fileName)': \(message)"
        }
    }
}
