// FileOperationsService.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 22.01.2026.
//  Copyright © 2026 Senatov. All rights reserved.

import AppKit
import Foundation

// MARK: - File Operation Errors
enum FileOperationError: LocalizedError {
    case fileNotFound(String)
    case fileAlreadyExists(String)
    case permissionDenied(String)
    case operationFailed(String)
    case invalidDestination(String)
    case conflict(source: URL, target: URL)
    case operationCancelled
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound(let name):
            return "File not found: \(name)"
        case .fileAlreadyExists(let name):
            return "File already exists: \(name)"
        case .permissionDenied(let path):
            return "Permission denied: \(path)"
        case .operationFailed(let reason):
            return "Operation failed: \(reason)"
        case .invalidDestination(let path):
            return "Invalid destination: \(path)"
        case .conflict(_, let target):
            return "File conflict: \(target.lastPathComponent)"
        case .operationCancelled:
            return "Operation cancelled"
        }
    }
}

// MARK: - Copy/Move Options
struct FileOperationOptions {
    var conflictResolution: ConflictResolution = .keepBoth
    var applyToAll: Bool = false
}

// MARK: - File Operations Service
/// Handles all file system operations: copy, move, delete, rename, pack, create link
@MainActor
final class FileOperationsService {
    
    static let shared = FileOperationsService()
    
    private let fileManager = FileManager.default
    
    private init() {}
    
    // MARK: - Check for conflict
    func checkConflict(source: URL, destination: URL) -> FileConflictInfo? {
        let targetURL = destination.appendingPathComponent(source.lastPathComponent)
        if fileManager.fileExists(atPath: targetURL.path) {
            return FileConflictInfo(source: source, target: targetURL)
        }
        return nil
    }
    
    // MARK: - Copy single file with resolution
    func copyFile(_ source: URL, to destination: URL, resolution: ConflictResolution) async throws -> URL {
        let targetURL = destination.appendingPathComponent(source.lastPathComponent)
        
        let finalURL: URL
        switch resolution {
        case .skip:
            return targetURL  // Just return existing, don't copy
            
        case .keepBoth:
            finalURL = generateUniqueName(for: targetURL)
            
        case .replace:
            if fileManager.fileExists(atPath: targetURL.path) {
                try fileManager.removeItem(at: targetURL)
            }
            finalURL = targetURL
            
        case .stop:
            throw FileOperationError.operationCancelled
        }
        
        try fileManager.copyItem(at: source, to: finalURL)
        log.info("Copied: \(source.lastPathComponent) → \(finalURL.path)")
        return finalURL
    }
    
    // MARK: - Move single file with resolution
    func moveFile(_ source: URL, to destination: URL, resolution: ConflictResolution) async throws -> URL {
        let targetURL = destination.appendingPathComponent(source.lastPathComponent)
        
        let finalURL: URL
        switch resolution {
        case .skip:
            return source  // Don't move, return original
            
        case .keepBoth:
            finalURL = generateUniqueName(for: targetURL)
            
        case .replace:
            if fileManager.fileExists(atPath: targetURL.path) {
                try fileManager.removeItem(at: targetURL)
            }
            finalURL = targetURL
            
        case .stop:
            throw FileOperationError.operationCancelled
        }
        
        try fileManager.moveItem(at: source, to: finalURL)
        log.info("Moved: \(source.lastPathComponent) → \(finalURL.path)")
        return finalURL
    }
    
    // MARK: - Copy files (legacy, auto keep-both)
    func copyFiles(_ files: [URL], to destination: URL) async throws -> [URL] {
        guard fileManager.fileExists(atPath: destination.path) else {
            throw FileOperationError.invalidDestination(destination.path)
        }
        
        var copiedFiles: [URL] = []
        
        for file in files {
            let finalURL = try await copyFile(file, to: destination, resolution: .keepBoth)
            copiedFiles.append(finalURL)
        }
        
        return copiedFiles
    }
    
    // MARK: - Move files (legacy, auto keep-both)
    func moveFiles(_ files: [URL], to destination: URL) async throws -> [URL] {
        guard fileManager.fileExists(atPath: destination.path) else {
            throw FileOperationError.invalidDestination(destination.path)
        }
        
        var movedFiles: [URL] = []
        
        for file in files {
            let finalURL = try await moveFile(file, to: destination, resolution: .keepBoth)
            movedFiles.append(finalURL)
        }
        
        return movedFiles
    }
    
    // MARK: - Delete files (move to Trash)
    func deleteFiles(_ files: [URL]) async throws -> [URL] {
        var trashedURLs: [URL] = []
        
        for file in files {
            var resultingURL: NSURL?
            try fileManager.trashItem(at: file, resultingItemURL: &resultingURL)
            if let trashURL = resultingURL as URL? {
                trashedURLs.append(trashURL)
            }
            log.info("Moved to Trash: \(file.lastPathComponent)")
        }
        
        return trashedURLs
    }
    
    // MARK: - Rename file
    func renameFile(_ file: URL, to newName: String) async throws -> URL {
        guard !newName.isEmpty else {
            throw FileOperationError.operationFailed("Name cannot be empty")
        }
        
        let parentDir = file.deletingLastPathComponent()
        let newURL = parentDir.appendingPathComponent(newName)
        
        if fileManager.fileExists(atPath: newURL.path) && newURL.path != file.path {
            throw FileOperationError.fileAlreadyExists(newName)
        }
        
        try fileManager.moveItem(at: file, to: newURL)
        log.info("Renamed: \(file.lastPathComponent) → \(newName)")
        
        return newURL
    }
    
    // MARK: - Create symbolic link
    func createSymbolicLink(to source: URL, at destination: URL, linkName: String? = nil) async throws -> URL {
        let name = linkName ?? "\(source.lastPathComponent) link"
        let linkURL = destination.appendingPathComponent(name)
        let finalURL = generateUniqueName(for: linkURL)
        
        try fileManager.createSymbolicLink(at: finalURL, withDestinationURL: source)
        log.info("Created symlink: \(finalURL.lastPathComponent) → \(source.path)")
        
        return finalURL
    }
    
    // MARK: - Get file/folder properties
    func getProperties(for file: URL) throws -> FileProperties {
        let attributes = try fileManager.attributesOfItem(atPath: file.path)
        
        let size = attributes[.size] as? Int64 ?? 0
        let created = attributes[.creationDate] as? Date
        let modified = attributes[.modificationDate] as? Date
        let type = attributes[.type] as? FileAttributeType
        let permissions = attributes[.posixPermissions] as? Int
        
        var totalSize = size
        var itemCount = 0
        
        if type == .typeDirectory {
            let (dirSize, count) = calculateDirectorySize(at: file)
            totalSize = dirSize
            itemCount = count
        }
        
        return FileProperties(
            url: file,
            size: totalSize,
            itemCount: itemCount,
            created: created,
            modified: modified,
            isDirectory: type == .typeDirectory,
            isSymlink: type == .typeSymbolicLink,
            permissions: permissions,
            isReadable: fileManager.isReadableFile(atPath: file.path),
            isWritable: fileManager.isWritableFile(atPath: file.path),
            isExecutable: fileManager.isExecutableFile(atPath: file.path)
        )
    }
    
    // MARK: - Calculate directory size
    private func calculateDirectorySize(at url: URL) -> (Int64, Int) {
        var totalSize: Int64 = 0
        var count = 0
        
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return (0, 0)
        }
        
        for case let fileURL as URL in enumerator {
            count += 1
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
                if resourceValues.isDirectory == false {
                    totalSize += Int64(resourceValues.fileSize ?? 0)
                }
            } catch {
                log.warning("Failed to get size for: \(fileURL.path)")
            }
        }
        
        return (totalSize, count)
    }
    
    // MARK: - Generate unique name (Keep Both)
    private func generateUniqueName(for url: URL) -> URL {
        guard fileManager.fileExists(atPath: url.path) else {
            return url
        }
        
        var finalURL = url
        var counter = 1
        
        let baseName = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        let parentDir = url.deletingLastPathComponent()
        
        while fileManager.fileExists(atPath: finalURL.path) {
            let newName = ext.isEmpty
                ? "\(baseName) (\(counter))"
                : "\(baseName) (\(counter)).\(ext)"
            finalURL = parentDir.appendingPathComponent(newName)
            counter += 1
            
            if counter > 1000 {
                log.error("Too many name conflicts for: \(url.path)")
                break
            }
        }
        
        return finalURL
    }
}

// MARK: - File Properties
struct FileProperties {
    let url: URL
    let size: Int64
    let itemCount: Int
    let created: Date?
    let modified: Date?
    let isDirectory: Bool
    let isSymlink: Bool
    let permissions: Int?
    let isReadable: Bool
    let isWritable: Bool
    let isExecutable: Bool
    
    var name: String { url.lastPathComponent }
    var path: String { url.path }
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    var permissionsString: String {
        guard let perms = permissions else { return "---" }
        return String(format: "%o", perms)
    }
}
