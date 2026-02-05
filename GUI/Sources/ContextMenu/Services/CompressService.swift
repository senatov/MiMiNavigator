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
    
    // MARK: - Compress Files (Finder-style)
    
    /// Compresses files using Finder-style naming (Archive.zip or item.zip)
    /// Returns URL of created archive
    @discardableResult
    func compress(files: [URL]) async throws -> URL {
        log.debug("\(#function) files.count=\(files.count) files=\(files.map { $0.lastPathComponent })")
        
        guard !files.isEmpty else {
            log.error("\(#function) FAILED: no files to compress")
            throw CompressError.noFilesToCompress
        }
        
        let parentDir = files[0].deletingLastPathComponent()
        let archiveName = generateArchiveName(for: files, in: parentDir)
        let archiveURL = parentDir.appendingPathComponent(archiveName)
        
        log.info("\(#function) compressing \(files.count) item(s) → '\(archiveName)'")
        
        // Use ditto for Finder-compatible compression
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        
        var args = ["-c", "-k", "--sequesterRsrc", "--keepParent"]
        args.append(contentsOf: files.map { $0.path })
        args.append(archiveURL.path)
        
        task.arguments = args
        log.debug("\(#function) ditto args: \(args.joined(separator: " "))")
        
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
        
        log.info("\(#function) SUCCESS created: '\(archiveURL.path)'")
        return archiveURL
    }
    
    // MARK: - Private Helpers
    
    /// Generates archive name following Finder conventions:
    /// - Single item: "ItemName.zip"
    /// - Multiple items: "Archive.zip" (or "Archive 2.zip" if exists)
    private func generateArchiveName(for files: [URL], in directory: URL) -> String {
        let baseName: String
        
        if files.count == 1 {
            // Single file: use its name
            let fileName = files[0].deletingPathExtension().lastPathComponent
            baseName = fileName
        } else {
            // Multiple files: use "Archive"
            baseName = "Archive"
        }
        
        var candidateName = "\(baseName).zip"
        var counter = 2
        
        while fileManager.fileExists(atPath: directory.appendingPathComponent(candidateName).path) {
            candidateName = "\(baseName) \(counter).zip"
            counter += 1
        }
        
        log.debug("\(#function) generated name='\(candidateName)' for \(files.count) file(s)")
        return candidateName
    }
}

// MARK: - Compress Errors
enum CompressError: LocalizedError {
    case noFilesToCompress
    case compressionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .noFilesToCompress:
            return "No files selected for compression"
        case .compressionFailed(let message):
            return "Compression failed: \(message)"
        }
    }
}
