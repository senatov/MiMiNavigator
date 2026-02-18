// ArchiveManager.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 11.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Central archive session coordinator — open, close, dirty tracking

import Foundation

// MARK: - Archive Manager
actor ArchiveManager {

    static let shared = ArchiveManager()

    private var sessions: [String: ArchiveSession] = [:]
    private var openingInProgress: Set<String> = []
    private let fm = FileManager.default

    private let baseTempDir: URL = {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("MiMiNavigator_archives", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    private init() {}

    // MARK: - Open

    func openArchive(at archiveURL: URL) async throws -> URL {
        let key = archiveURL.path

        if let existing = sessions[key] {
            return existing.tempDirectory
        }

        if openingInProgress.contains(key) {
            for _ in 0..<30 {
                try await Task.sleep(nanoseconds: 100_000_000)
                if let existing = sessions[key] { return existing.tempDirectory }
            }
            throw ArchiveManagerError.extractionFailed("Timeout waiting for: \(archiveURL.lastPathComponent)")
        }
        openingInProgress.insert(key)

        guard let format = ArchiveFormatDetector.detect(url: archiveURL) else {
            openingInProgress.remove(key)
            throw ArchiveManagerError.unsupportedFormat(archiveURL.pathExtension)
        }

        let tempDir = baseTempDir.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let attrs = (try? fm.attributesOfItem(atPath: archiveURL.path)) ?? [:]

        do {
            try await ArchiveExtractor.extract(archiveURL: archiveURL, format: format, to: tempDir)
        } catch {
            openingInProgress.remove(key)
            try? fm.removeItem(at: tempDir)
            throw error
        }

        // Snapshot mtime of every extracted file AFTER extraction completes.
        // scanForChanges() compares against this to detect real user edits.
        let snapshot = snapshotMtimes(in: tempDir)

        let session = ArchiveSession(
            archiveURL:               archiveURL,
            tempDirectory:            tempDir,
            format:                   format,
            isDirty:                  false,
            originalPosixPermissions: (attrs[.posixPermissions] as? NSNumber)?.int16Value ?? 0o644,
            originalModificationDate: attrs[.modificationDate] as? Date,
            originalCreationDate:     attrs[.creationDate] as? Date,
            originalOwnerName:        (attrs[.ownerAccountName] as? String) ?? "",
            baselineSnapshot:         snapshot
        )

        sessions[key] = session
        openingInProgress.remove(key)
        log.info("[ArchiveManager] Opened: \(archiveURL.lastPathComponent)")
        return tempDir
    }

    // MARK: - Close

    func closeArchive(at archiveURL: URL, repackIfDirty: Bool) async throws {
        let key = archiveURL.path
        guard var session = sessions[key] else { return }

        defer {
            try? fm.removeItem(at: session.tempDirectory)
            sessions.removeValue(forKey: key)
        }

        if repackIfDirty {
            session.isDirty = session.isDirty || scanForChanges(in: session)
        }

        if session.isDirty && repackIfDirty {
            log.info("[ArchiveManager] Repacking: \(archiveURL.lastPathComponent)")
            try await ArchiveRepacker.repack(session: session)
        }
    }

    // MARK: - Dirty

    func markDirty(archivePath: String) {
        sessions[archivePath]?.isDirty = true
    }

    func markDirtyByTempPath(_ tempPath: String) {
        for key in sessions.keys where tempPath.hasPrefix(sessions[key]!.tempDirectory.path) {
            sessions[key]?.isDirty = true
        }
    }

    func isDirty(archiveURL: URL) -> Bool {
        guard let session = sessions[archiveURL.path] else { return false }
        return session.isDirty || scanForChanges(in: session)
    }

    // MARK: - Query

    func sessionForArchive(at archiveURL: URL) -> ArchiveSession? {
        sessions[archiveURL.path]
    }

    func sessionForPath(_ path: String) -> ArchiveSession? {
        sessions.values.first { path.hasPrefix($0.tempDirectory.path) }
    }

    func isInsideArchive(path: String) -> Bool {
        sessionForPath(path) != nil
    }

    func archiveURL(forTempPath tempPath: String) -> URL? {
        sessionForPath(tempPath)?.archiveURL
    }

    // MARK: - Cleanup

    func cleanup() {
        sessions.values.forEach { try? fm.removeItem(at: $0.tempDirectory) }
        sessions.removeAll()
        try? fm.removeItem(at: baseTempDir)
    }

    // MARK: - Private

    /// Build a relative-path → mtime snapshot of every file in tempDir.
    private func snapshotMtimes(in tempDir: URL) -> [String: Date] {
        var snap: [String: Date] = [:]
        guard let enumerator = fm.enumerator(
            at: tempDir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles
        ) else { return snap }

        let base = tempDir.standardizedFileURL.path
        while let url = enumerator.nextObject() as? URL {
            let rel = String(url.standardizedFileURL.path.dropFirst(base.count))
            if let mtime = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate {
                snap[rel] = mtime
            }
        }
        return snap
    }

    /// Returns true only if any extracted file was modified or added after extraction.
    /// Compares against the baseline snapshot taken right after extraction — immune to
    /// extraction-time mtime artifacts that fooled the old creationDate approach.
    private func scanForChanges(in session: ArchiveSession) -> Bool {
        let snap = session.baselineSnapshot
        guard let enumerator = fm.enumerator(
            at: session.tempDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles
        ) else { return false }

        let base = session.tempDirectory.standardizedFileURL.path
        while let url = enumerator.nextObject() as? URL {
            let rel = String(url.standardizedFileURL.path.dropFirst(base.count))
            guard let mtime = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            else { continue }

            if let baseline = snap[rel] {
                // Known file — dirty if mtime moved forward by more than 1 second
                if mtime.timeIntervalSince(baseline) > 1 { return true }
            } else {
                // New file added after extraction — definitely dirty
                return true
            }
        }
        return false
    }
}
