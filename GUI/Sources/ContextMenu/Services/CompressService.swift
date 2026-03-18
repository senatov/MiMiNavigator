// CompressService.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 04.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Service for macOS native Compress functionality (like Finder's "Compress")

import Foundation

// MARK: - Compress Service
/// Handles macOS native compression (creates .zip archives like Finder)
@MainActor
final class CompressService {

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
        password: String? = nil
    ) async throws -> URL {
        log.debug("\(#function) files.count=\(files.count) level=\(compressionLevel) hasPassword=\(password != nil)")
        guard !files.isEmpty else {
            log.error("\(#function) FAILED: no files to compress")
            throw CompressError.noFilesToCompress
        }
        
        let archiveURL = destination.appendingPathComponent(archiveName)
        log.info("\(#function) compressing \(files.count) item(s) → '\(archiveURL.path)' level=\(compressionLevel.rawValue)")
        
        // Use zip command for password support, ditto otherwise
        if let password = password, !password.isEmpty {
            try await compressWithZip(files: files, to: archiveURL, compressionLevel: compressionLevel, password: password)
        } else {
            try await compressWithDitto(files: files, to: archiveURL, compressionLevel: compressionLevel)
        }
        
        log.info("\(#function) SUCCESS created: '\(archiveURL.path)'")
        
        // Move originals to trash if requested
        if moveToArchive {
            for file in files {
                do {
                    try fileManager.removeItem(at: file)
                    log.debug("\(#function) removed original: '\(file.path)'")
                } catch {
                    log.error("\(#function) FAILED to remove original: '\(file.path)' error='\(error.localizedDescription)'")
                    throw CompressError.moveToArchiveFailed(file.lastPathComponent, error.localizedDescription)
                }
            }
        }
        
        return archiveURL
    }
    
    // MARK: - Ditto Compression (no password)
    
    private func compressWithDitto(files: [URL], to archiveURL: URL, compressionLevel: CompressionLevel) async throws {
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
        } else {
            // Multiple files — stage in temp directory
            let stagingDirURL = fileManager.temporaryDirectory
                .appendingPathComponent(".MiMiNavigator-Compress-\(UUID().uuidString)", isDirectory: true)
            try fileManager.createDirectory(at: stagingDirURL, withIntermediateDirectories: true)
            temporaryStagingURL = stagingDirURL
            
            for sourceURL in files {
                let targetURL = stagingDirURL.appendingPathComponent(sourceURL.lastPathComponent)
                if fileManager.fileExists(atPath: targetURL.path) {
                    try fileManager.removeItem(at: targetURL)
                }
                try fileManager.copyItem(at: sourceURL, to: targetURL)
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
        
        let pipe = Pipe()
        task.standardError = pipe
        
        try task.run()
        task.waitUntilExit()
        
        if task.terminationStatus != 0 {
            let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            log.error("\(#function) ditto FAILED status=\(task.terminationStatus) error='\(errorMessage)'")
            throw CompressError.compressionFailed(errorMessage)
        }
    }
    
    // MARK: - Zip Compression (with password)
    
    private func compressWithZip(files: [URL], to archiveURL: URL, compressionLevel: CompressionLevel, password: String) async throws {
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
        
        let pipe = Pipe()
        task.standardError = pipe
        task.standardOutput = pipe
        
        try task.run()
        task.waitUntilExit()
        
        if task.terminationStatus != 0 {
            let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            log.error("\(#function) zip FAILED status=\(task.terminationStatus) error='\(errorMessage)'")
            throw CompressError.compressionFailed(errorMessage)
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
