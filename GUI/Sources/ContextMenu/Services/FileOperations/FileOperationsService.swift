// FileOperationsService.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 22.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Core file operations service — copy, move, conflict detection.
//   Extensions: FileOpsService+Delete, +Rename, +SymLink

import AppKit
import Foundation

// MARK: - File Operations Service
/// Singleton service for file system operations: copy, move, conflict detection.
/// Delete, rename, symlink are in separate extension files.
@MainActor
final class FileOperationsService {

    static let shared = FileOperationsService()
    let fileManager = FileManager.default

    private init() {
        log.debug("[FileOps] initialized")
    }

    // MARK: - Conflict Detection
    func checkConflict(source: URL, destination: URL) -> FileConflictInfo? {
        let targetURL = destination.appendingPathComponent(source.lastPathComponent)
        guard fileManager.fileExists(atPath: targetURL.path) else { return nil }
        log.debug("[FileOps] conflict detected: '\(targetURL.lastPathComponent)'")
        return FileConflictInfo(source: source, target: targetURL)
    }

    // MARK: - Copy Single File
    func copyFile(_ source: URL, to destination: URL, resolution: ConflictResolution) async throws -> URL {
        log.debug("[FileOps] copy '\(source.lastPathComponent)' → '\(destination.path)' [\(resolution)]")
        let targetURL = destination.appendingPathComponent(source.lastPathComponent)
        let finalURL = try resolveConflict(targetURL: targetURL, source: source, resolution: resolution)
        try fileManager.copyItem(at: source, to: finalURL)
        log.info("[FileOps] ✅ copied: '\(source.lastPathComponent)' → '\(finalURL.lastPathComponent)'")
        return finalURL
    }

    // MARK: - Copy Multiple Files
    func copyFiles(_ files: [URL], to destination: URL) async throws -> [URL] {
        try validateDestination(destination)
        var result: [URL] = []
        for file in files {
            let url = try await copyFile(file, to: destination, resolution: .keepBoth)
            result.append(url)
        }
        return result
    }

    // MARK: - Move Single File
    func moveFile(_ source: URL, to destination: URL, resolution: ConflictResolution) async throws -> URL {
        log.debug("[FileOps] move '\(source.lastPathComponent)' → '\(destination.path)' [\(resolution)]")
        let targetURL = destination.appendingPathComponent(source.lastPathComponent)
        if case .skip = resolution {
            log.debug("[FileOps] skipped move: '\(source.lastPathComponent)'")
            return source
        }
        let finalURL = try resolveConflict(targetURL: targetURL, source: source, resolution: resolution)
        try fileManager.moveItem(at: source, to: finalURL)
        log.info("[FileOps] ✅ moved: '\(source.lastPathComponent)' → '\(finalURL.lastPathComponent)'")
        return finalURL
    }

    // MARK: - Move Multiple Files
    func moveFiles(_ files: [URL], to destination: URL) async throws -> [URL] {
        try validateDestination(destination)
        var result: [URL] = []
        for file in files {
            let url = try await moveFile(file, to: destination, resolution: .keepBoth)
            result.append(url)
        }
        return result
    }
}

// MARK: - Private Helpers
private extension FileOperationsService {

    func validateDestination(_ destination: URL) throws {
        guard fileManager.fileExists(atPath: destination.path) else {
            throw FileOperationError.invalidDestination(destination.path)
        }
    }

    func resolveConflict(targetURL: URL, source: URL, resolution: ConflictResolution) throws -> URL {
        switch resolution {
        case .skip:
            return targetURL
        case .keepBoth:
            return UniqueNameGenerator.generate(for: targetURL, fileManager: fileManager)
        case .replace:
            if fileManager.fileExists(atPath: targetURL.path) {
                try fileManager.removeItem(at: targetURL)
            }
            return targetURL
        case .stop:
            throw FileOperationError.operationCancelled
        }
    }
}
