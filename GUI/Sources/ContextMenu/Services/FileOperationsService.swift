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
        }
    }
}

// MARK: - File Operations Service
/// Handles all file system operations: copy, move, delete, rename, pack, create link
@MainActor
final class FileOperationsService {
    
    static let shared = FileOperationsService()
    
    private let fileManager = FileManager.default
    
    private init() {}
    
    // MARK: - Copy files to destination
    func copyFiles(_ files: [URL], to destination: URL) async throws -> [URL] {
        guard fileManager.fileExists(atPath: destination.path) else {
            throw FileOperationError.invalidDestination(destination.path)
        }
        
        var copiedFiles: [URL] = []
        
        for file in files {
            let destinationURL = destination.appendingPathComponent(file.lastPathComponent)
            let finalURL = try resolveNameConflict(for: destinationURL)
            
            try fileManager.copyItem(at: file, to: finalURL)
            copiedFiles.append(finalURL)
            log.info("Copied: \(file.lastPathComponent) → \(destination.path)")
        }
        
        return copiedFiles
    }
    
    // MARK: - Move files to destination
    func moveFiles(_ files: [URL], to destination: URL) async throws -> [URL] {
        guard fileManager.fileExists(atPath: destination.path) else {
            throw FileOperationError.invalidDestination(destination.path)
        }
        
        var movedFiles: [URL] = []
        
        for file in files {
            let destinationURL = destination.appendingPathComponent(file.lastPathComponent)
            let finalURL = try resolveNameConflict(for: destinationURL)
            
            try fileManager.moveItem(at: file, to: finalURL)
            movedFiles.append(finalURL)
            log.info("Moved: \(file.lastPathComponent) → \(destination.path)")
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
        
        // Check if name already exists (and it's not the same file)
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
        let finalURL = try resolveNameConflict(for: linkURL)
        
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
        
        // For directories, calculate total size
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
    
    // MARK: - Resolve name conflicts
    private func resolveNameConflict(for url: URL) throws -> URL {
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
                throw FileOperationError.operationFailed("Too many name conflicts")
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
