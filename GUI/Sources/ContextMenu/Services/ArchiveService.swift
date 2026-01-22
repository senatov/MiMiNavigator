// ArchiveService.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 22.01.2026.
//  Copyright © 2026 Senatov. All rights reserved.

import Foundation

// MARK: - Archive Format
enum ArchiveFormat: String, CaseIterable, Identifiable, Sendable {
    case zip = "zip"
    case tarGz = "tar.gz"
    case tarBz2 = "tar.bz2"
    case tar = "tar"
    case sevenZip = "7z"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .zip: return "ZIP Archive"
        case .tarGz: return "TAR.GZ (gzip compressed)"
        case .tarBz2: return "TAR.BZ2 (bzip2 compressed)"
        case .tar: return "TAR Archive (uncompressed)"
        case .sevenZip: return "7-Zip Archive"
        }
    }
    
    var fileExtension: String { rawValue }
    
    var icon: String {
        switch self {
        case .zip: return "doc.zipper"
        case .tarGz, .tarBz2, .tar: return "archivebox"
        case .sevenZip: return "archivebox.fill"
        }
    }
    
    /// Check if format is available on this system
    var isAvailable: Bool {
        switch self {
        case .zip, .tar, .tarGz, .tarBz2:
            return true  // Built-in macOS tools
        case .sevenZip:
            return ArchiveFormat.check7zAvailable()
        }
    }
    
    /// Static check for 7z availability (no actor isolation needed)
    private static func check7zAvailable() -> Bool {
        let paths = [
            "/usr/local/bin/7z",
            "/opt/homebrew/bin/7z",
            "/usr/bin/7z"
        ]
        return paths.contains { FileManager.default.fileExists(atPath: $0) }
    }
    
    static var availableFormats: [ArchiveFormat] {
        allCases.filter { $0.isAvailable }
    }
}

// MARK: - Archive Service
/// Handles archive creation and extraction
@MainActor
final class ArchiveService {
    
    static let shared = ArchiveService()
    
    private let fileManager = FileManager.default
    
    private init() {}
    
    // MARK: - Get 7z path
    private var sevenZipPath: String? {
        let paths = [
            "/opt/homebrew/bin/7z",
            "/usr/local/bin/7z",
            "/usr/bin/7z"
        ]
        return paths.first { fileManager.fileExists(atPath: $0) }
    }
    
    // MARK: - Create archive
    /// Creates an archive from files
    /// - Parameters:
    ///   - files: Files to archive
    ///   - destination: Directory where archive will be created
    ///   - archiveName: Name for the archive (without extension)
    ///   - format: Archive format
    /// - Returns: URL of created archive
    func createArchive(
        from files: [URL],
        to destination: URL,
        archiveName: String,
        format: ArchiveFormat
    ) async throws -> URL {
        
        let archiveURL = destination.appendingPathComponent("\(archiveName).\(format.fileExtension)")
        
        // Check if archive already exists
        if fileManager.fileExists(atPath: archiveURL.path) {
            throw FileOperationError.fileAlreadyExists(archiveURL.lastPathComponent)
        }
        
        switch format {
        case .zip:
            try await createZipArchive(from: files, to: archiveURL)
        case .tar:
            try await createTarArchive(from: files, to: archiveURL, compression: nil)
        case .tarGz:
            try await createTarArchive(from: files, to: archiveURL, compression: "gzip")
        case .tarBz2:
            try await createTarArchive(from: files, to: archiveURL, compression: "bzip2")
        case .sevenZip:
            try await create7zArchive(from: files, to: archiveURL)
        }
        
        log.info("Created archive: \(archiveURL.lastPathComponent)")
        return archiveURL
    }
    
    // MARK: - ZIP using ditto (macOS native, preserves attributes)
    private func createZipArchive(from files: [URL], to archiveURL: URL) async throws {
        // Use ditto for single item, or create temp directory for multiple
        if files.count == 1 {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            process.arguments = ["-c", "-k", "--sequesterRsrc", files[0].path, archiveURL.path]
            
            try await runProcess(process)
        } else {
            // For multiple files, use zip command
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
            process.currentDirectoryURL = files[0].deletingLastPathComponent()
            
            var args = ["-r", archiveURL.path]
            args.append(contentsOf: files.map { $0.lastPathComponent })
            process.arguments = args
            
            try await runProcess(process)
        }
    }
    
    // MARK: - TAR archive
    private func createTarArchive(from files: [URL], to archiveURL: URL, compression: String?) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        process.currentDirectoryURL = files[0].deletingLastPathComponent()
        
        var args = ["-c"]
        
        // Add compression flag
        if let comp = compression {
            switch comp {
            case "gzip": args.append("-z")
            case "bzip2": args.append("-j")
            default: break
            }
        }
        
        args.append("-f")
        args.append(archiveURL.path)
        args.append(contentsOf: files.map { $0.lastPathComponent })
        
        process.arguments = args
        
        try await runProcess(process)
    }
    
    // MARK: - 7z archive
    private func create7zArchive(from files: [URL], to archiveURL: URL) async throws {
        guard let szPath = sevenZipPath else {
            throw FileOperationError.operationFailed("7-Zip not installed. Install with: brew install p7zip")
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: szPath)
        process.currentDirectoryURL = files[0].deletingLastPathComponent()
        
        var args = ["a", archiveURL.path]
        args.append(contentsOf: files.map { $0.lastPathComponent })
        process.arguments = args
        
        try await runProcess(process)
    }
    
    // MARK: - Run process async
    private func runProcess(_ process: Process) async throws {
        let errorPipe = Pipe()
        process.standardError = errorPipe
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            process.terminationHandler = { proc in
                if proc.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                    continuation.resume(throwing: FileOperationError.operationFailed(errorMessage))
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
