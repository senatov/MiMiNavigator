// FileOpsService.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 22.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Core file operations service — copy, move, conflict detection, batch transfer helpers.
//   Extensions: FileOpsService+Delete, +Rename, +SymLink

import AppKit
import Foundation

// MARK: - File Operations Service
/// Singleton service for file system operations: copy, move, conflict detection.
/// Delete, rename, symlink are in separate extension files.
@MainActor
final class FileOpsService {

    static let shared = FileOpsService()
    let fileManager = FileManager.default

    private enum Constants {
        static let keepBothResolution: ConflictResolution = .keepBoth
    }

    private init() {
        log.debug("[FileOps] initialized")
    }

    private func performBatchTransfer(
        _ files: [URL],
        to destination: URL,
        operation: (URL, URL) async throws -> URL
    ) async throws -> [URL] {
        try validateDestination(destination)

        var result: [URL] = []
        result.reserveCapacity(files.count)

        for file in files {
            let transferredURL = try await operation(file, destination)
            result.append(transferredURL)
        }

        return result
    }

    private func makeTargetURL(for source: URL, destination: URL) -> URL {
        destination.appendingPathComponent(source.lastPathComponent)
    }

    // MARK: - Helpers

    // MARK: - Conflict Detection
    func checkConflict(source: URL, destination: URL) -> FileConflictInfo? {
        let targetURL = makeTargetURL(for: source, destination: destination)
        guard fileManager.fileExists(atPath: targetURL.path) else { return nil }
        log.debug("[FileOps] conflict detected: '\(targetURL.lastPathComponent)'")
        return FileConflictInfo(source: source, target: targetURL)
    }

    // MARK: - Copy Single File
    func copyFile(_ source: URL, to destination: URL, resolution: ConflictResolution) async throws -> URL {
        log.debug("[FileOps] copy '\(source.lastPathComponent)'")
        log.debug("[FileOps] destination='\(destination.path)' resolution=\(resolution)")

        let targetURL = makeTargetURL(for: source, destination: destination)
        let finalURL = try resolveConflict(targetURL: targetURL, source: source, resolution: resolution)

        try fileManager.copyItem(at: source, to: finalURL)

        log.info("[FileOps] ✅ copied: '\(source.lastPathComponent)'")
        log.info("[FileOps] final name='\(finalURL.lastPathComponent)'")
        return finalURL
    }

    // MARK: - Copy Multiple Files
    func copyFiles(_ files: [URL], to destination: URL) async throws -> [URL] {
        try await performBatchTransfer(files, to: destination) { file, destination in
            try await self.copyFile(file, to: destination, resolution: Constants.keepBothResolution)
        }
    }

    // MARK: - Move Single File
    func moveFile(_ source: URL, to destination: URL, resolution: ConflictResolution) async throws -> URL {
        log.debug("[FileOps] move '\(source.lastPathComponent)'")
        log.debug("[FileOps] destination='\(destination.path)' resolution=\(resolution)")

        let targetURL = makeTargetURL(for: source, destination: destination)
        if case .skip = resolution {
            log.debug("[FileOps] skipped move: '\(source.lastPathComponent)'")
            return source
        }

        let finalURL = try resolveConflict(targetURL: targetURL, source: source, resolution: resolution)
        try fileManager.moveItem(at: source, to: finalURL)

        log.info("[FileOps] ✅ moved: '\(source.lastPathComponent)'")
        log.info("[FileOps] final name='\(finalURL.lastPathComponent)'")
        return finalURL
    }

    // MARK: - Move Multiple Files
    func moveFiles(_ files: [URL], to destination: URL) async throws -> [URL] {
        try await performBatchTransfer(files, to: destination) { file, destination in
            try await self.moveFile(file, to: destination, resolution: Constants.keepBothResolution)
        }
    }
}
