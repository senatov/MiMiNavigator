// FileOperationsService.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 22.01.2026.
// Refactored: 27.01.2026
// Copyright © 2026 Senatov. All rights reserved.
// Description: Main service for file system operations

import AppKit
import Foundation

// MARK: - File Operations Service
/// Handles all file system operations: copy, move, delete, rename, create link
@MainActor
final class FileOperationsService {

    static let shared = FileOperationsService()
    private let fileManager = FileManager.default

    private init() {
        log.debug("[FileOperationsService] initialized")
    }

    // MARK: - Conflict Detection

    func checkConflict(source: URL, destination: URL) -> FileConflictInfo? {
        let targetURL = destination.appendingPathComponent(source.lastPathComponent)

        if fileManager.fileExists(atPath: targetURL.path) {
            log.debug("[FileOperationsService] conflict: \(targetURL.lastPathComponent)")
            return FileConflictInfo(source: source, target: targetURL)
        }
        return nil
    }

    // MARK: - Copy Operations

    func copyFile(_ source: URL, to destination: URL, resolution: ConflictResolution) async throws -> URL {
        log.debug("[FileOperationsService] copy \(source.lastPathComponent) → \(destination.path) [\(resolution)]")

        let targetURL = destination.appendingPathComponent(source.lastPathComponent)
        let finalURL: URL

        switch resolution {
            case .skip:
                log.debug("[FileOperationsService] skipped: \(source.lastPathComponent)")
                return targetURL

            case .keepBoth:
                finalURL = UniqueNameGenerator.generate(for: targetURL, fileManager: fileManager)

            case .replace:
                if fileManager.fileExists(atPath: targetURL.path) {
                    try fileManager.removeItem(at: targetURL)
                }
                finalURL = targetURL

            case .stop:
                throw FileOperationError.operationCancelled
        }

        try fileManager.copyItem(at: source, to: finalURL)
        log.info("[FileOperationsService] copied: \(source.lastPathComponent) → \(finalURL.lastPathComponent)")
        return finalURL
    }

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

    // MARK: - Move Operations

    func moveFile(_ source: URL, to destination: URL, resolution: ConflictResolution) async throws -> URL {
        log.debug("[FileOperationsService] move \(source.lastPathComponent) → \(destination.path) [\(resolution)]")

        let targetURL = destination.appendingPathComponent(source.lastPathComponent)
        let finalURL: URL

        switch resolution {
            case .skip:
                log.debug("[FileOperationsService] skipped: \(source.lastPathComponent)")
                return source

            case .keepBoth:
                finalURL = UniqueNameGenerator.generate(for: targetURL, fileManager: fileManager)

            case .replace:
                if fileManager.fileExists(atPath: targetURL.path) {
                    try fileManager.removeItem(at: targetURL)
                }
                finalURL = targetURL

            case .stop:
                throw FileOperationError.operationCancelled
        }

        try fileManager.moveItem(at: source, to: finalURL)
        log.info("[FileOperationsService] moved: \(source.lastPathComponent) → \(finalURL.lastPathComponent)")
        return finalURL
    }

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
}

// MARK: - Delete Operations
extension FileOperationsService {

    func deleteFiles(_ files: [URL]) async throws -> [URL] {
        var trashedURLs: [URL] = []

        for file in files {
            var resultingURL: NSURL?
            try fileManager.trashItem(at: file, resultingItemURL: &resultingURL)

            if let trashURL = resultingURL as URL? {
                trashedURLs.append(trashURL)
            }
            log.info("[FileOperationsService] trashed: \(file.lastPathComponent)")
        }

        return trashedURLs
    }
}

// MARK: - Rename Operations
extension FileOperationsService {

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
        log.info("[FileOperationsService] renamed: \(file.lastPathComponent) → \(newName)")

        return newURL
    }
}

// MARK: - Symbolic Link Operations
extension FileOperationsService {

    func createSymbolicLink(to source: URL, at destination: URL, linkName: String? = nil) async throws -> URL {
        let name = linkName ?? "\(source.lastPathComponent) link"
        let linkURL = destination.appendingPathComponent(name)
        let finalURL = UniqueNameGenerator.generate(for: linkURL, fileManager: fileManager)

        try fileManager.createSymbolicLink(at: finalURL, withDestinationURL: source)
        log.info("[FileOperationsService] symlink created: \(finalURL.lastPathComponent) → \(source.path)")

        return finalURL
    }
}
