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

    /// Callback to present the conflict dialog and await user's decision.
    /// Set by CntMenuCoord at init time.
    var conflictHandler: ((FileConflictInfo, Int) async -> BatchConflictDecision)?

    private init() {
        log.debug("[FileOps] initialized")
    }


    private func makeTargetURL(for source: URL, destination: URL) -> URL {
        destination.appendingPathComponent(source.lastPathComponent)
    }


    // MARK: - Conflict Detection

    func checkConflict(source: URL, destination: URL) -> FileConflictInfo? {
        let targetURL = makeTargetURL(for: source, destination: destination)
        guard fileManager.fileExists(atPath: targetURL.path) else { return nil }
        log.debug("[FileOps] conflict detected: '\(targetURL.lastPathComponent)'")
        return FileConflictInfo(source: source, target: targetURL)
    }


    // MARK: - Copy Single File

    func copyFile(_ source: URL, to destination: URL, resolution: ConflictResolution) async throws -> URL {
        let targetURL = makeTargetURL(for: source, destination: destination)
        let finalURL = try resolveConflict(targetURL: targetURL, source: source, resolution: resolution)
        try fileManager.copyItem(at: source, to: finalURL)
        log.info("[FileOps] copied: '\(source.lastPathComponent)' → '\(finalURL.lastPathComponent)'")
        return finalURL
    }


    // MARK: - Move Single File

    func moveFile(_ source: URL, to destination: URL, resolution: ConflictResolution) async throws -> URL {
        let targetURL = makeTargetURL(for: source, destination: destination)
        if case .skip = resolution {
            log.debug("[FileOps] skipped: '\(source.lastPathComponent)'")
            return source
        }
        let finalURL = try resolveConflict(targetURL: targetURL, source: source, resolution: resolution)
        try fileManager.moveItem(at: source, to: finalURL)
        log.info("[FileOps] moved: '\(source.lastPathComponent)' → '\(finalURL.lastPathComponent)'")
        return finalURL
    }


    // MARK: - Batch Copy (with conflict popup)

    func copyFiles(_ files: [URL], to destination: URL) async throws -> [URL] {
        try await batchTransfer(files, to: destination) { source, dest, resolution in
            try await self.copyFile(source, to: dest, resolution: resolution)
        }
    }


    // MARK: - Batch Move (with conflict popup)

    func moveFiles(_ files: [URL], to destination: URL) async throws -> [URL] {
        try await batchTransfer(files, to: destination) { source, dest, resolution in
            try await self.moveFile(source, to: dest, resolution: resolution)
        }
    }


    // MARK: - Batch Transfer with Conflict Resolution

    /// Process files one by one; on conflict show the dialog (unless "apply to all" was chosen).
    /// Returns URLs of successfully transferred files.
    private func batchTransfer(
        _ files: [URL],
        to destination: URL,
        operation: (URL, URL, ConflictResolution) async throws -> URL
    ) async throws -> [URL] {
        try validateDestination(destination)

        var results: [URL] = []
        results.reserveCapacity(files.count)
        var memorizedResolution: ConflictResolution?

        for (index, file) in files.enumerated() {
            let remaining = files.count - index

            // check for conflict
            if let conflict = checkConflict(source: file, destination: destination) {
                let resolution: ConflictResolution

                if let memo = memorizedResolution {
                    // "apply to all" was set — reuse without dialog
                    resolution = memo
                    log.debug("[FileOps] auto-resolved '\(file.lastPathComponent)' → \(memo)")
                } else if let handler = conflictHandler {
                    // show dialog
                    let decision = await handler(conflict, remaining)
                    resolution = decision.resolution
                    if decision.applyToAll {
                        memorizedResolution = resolution
                        log.info("[FileOps] 'apply to all' set → \(resolution) for \(remaining) remaining files")
                    }
                } else {
                    // no handler — default keepBoth
                    resolution = .keepBoth
                    log.warning("[FileOps] no conflict handler — defaulting to keepBoth")
                }

                // handle stop
                if resolution == .stop {
                    log.info("[FileOps] batch stopped by user at file \(index + 1)/\(files.count)")
                    break
                }
                // handle skip
                if resolution == .skip {
                    log.debug("[FileOps] skipped '\(file.lastPathComponent)'")
                    continue
                }

                let url = try await operation(file, destination, resolution)
                results.append(url)
            } else {
                // no conflict — just do it
                let url = try await operation(file, destination, .keepBoth)
                results.append(url)
            }
        }

        return results
    }
}
