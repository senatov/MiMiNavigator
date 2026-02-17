// ArchiveManager.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 11.02.2026.
// Refactored: 12.02.2026 — split into Manager + Extractor + Repacker
// Copyright © 2026 Senatov. All rights reserved.
// Description: Central archive session coordinator — delegates extraction/repacking to sub-modules

import Foundation

// MARK: - Archive Session
/// Tracks state of a single opened archive
struct ArchiveSession: Sendable {
    let archiveURL: URL
    let tempDirectory: URL
    let format: ArchiveFormat
    var isDirty: Bool = false
    let originalPosixPermissions: Int16
    let originalModificationDate: Date?
    let originalOwnerName: String
}

// MARK: - Archive Manager
/// Actor managing archive session lifecycle: open, close, dirty tracking.
/// Delegates extraction to ArchiveExtractor, repacking to ArchiveRepacker.
actor ArchiveManager {
    static let shared = ArchiveManager()
    private var sessions: [String: ArchiveSession] = [:]
    /// Archives currently being opened (prevents double-click race condition)
    private var openingInProgress: Set<String> = []
    private let fm = FileManager.default
    private let baseTempDir: URL = {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("MiMiNavigator_archives", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }()

    private init() {}

    // MARK: - Open Archive

    func openArchive(at archiveURL: URL) async throws -> URL {
        log.debug(#function)
        let key = archiveURL.path

        // Already open — return existing session
        if let existing = sessions[key] {
            log.info("[ArchiveManager] Already open: \(archiveURL.lastPathComponent)")
            return existing.tempDirectory
        }

        // Opening already in progress (double-click race) — wait and return when done
        if openingInProgress.contains(key) {
            log.warning("[ArchiveManager] Already opening: \(archiveURL.lastPathComponent) — ignoring duplicate request")
            // Poll until session appears (max ~3s)
            for _ in 0..<30 {
                try await Task.sleep(nanoseconds: 100_000_000) // 100ms
                if let existing = sessions[key] {
                    return existing.tempDirectory
                }
            }
            throw ArchiveManagerError.extractionFailed("Timed out waiting for duplicate open: \(archiveURL.lastPathComponent)")
        }
        openingInProgress.insert(key)

        guard let format = ArchiveFormatDetector.detect(url: archiveURL) else {
            throw ArchiveManagerError.unsupportedFormat(archiveURL.pathExtension)
        }

        let sessionID = UUID().uuidString
        let tempDir = baseTempDir.appendingPathComponent(sessionID, isDirectory: true)
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)

        log.debug("[ArchiveManager] Opening \(archiveURL.lastPathComponent) → \(tempDir.path)")

        // Snapshot original attributes
        let attrs = try fm.attributesOfItem(atPath: archiveURL.path)
        let permissions = (attrs[.posixPermissions] as? NSNumber)?.int16Value ?? 0o644
        let modDate = attrs[.modificationDate] as? Date
        let owner = (attrs[.ownerAccountName] as? String) ?? ""

        // Delegate extraction (clear in-progress flag on exit regardless of outcome)
        do {
            try await ArchiveExtractor.extract(archiveURL: archiveURL, format: format, to: tempDir)
        } catch {
            openingInProgress.remove(key)
            try? fm.removeItem(at: tempDir)
            log.error("[ArchiveManager] Extraction failed for \(archiveURL.lastPathComponent): \(error.localizedDescription)")
            throw error
        }

        let session = ArchiveSession(
            archiveURL: archiveURL, tempDirectory: tempDir, format: format,
            isDirty: false, originalPosixPermissions: permissions,
            originalModificationDate: modDate, originalOwnerName: owner
        )
        sessions[key] = session
        openingInProgress.remove(key)

        log.info("[ArchiveManager] Opened successfully: \(archiveURL.lastPathComponent) → \(tempDir.path)")
        return tempDir
    }

    // MARK: - Close Archive

    func closeArchive(at archiveURL: URL, repackIfDirty: Bool = true) async throws {
        log.debug(#function)
        let key = archiveURL.path
        guard var session = sessions[key] else {
            log.warning("[ArchiveManager] No session for: \(archiveURL.lastPathComponent)")
            return
        }

        if repackIfDirty {
            let dirtyCheck = checkDirty(session: session)
            session.isDirty = session.isDirty || dirtyCheck
        }

        if session.isDirty && repackIfDirty {
            log.info("[ArchiveManager] Repacking dirty: \(archiveURL.lastPathComponent)")
            try await ArchiveRepacker.repack(session: session)
        }

        try? fm.removeItem(at: session.tempDirectory)
        sessions.removeValue(forKey: key)
        log.info("[ArchiveManager] Closed: \(archiveURL.lastPathComponent)")
    }

    // MARK: - Query

    func sessionForPath(_ path: String) -> ArchiveSession? {
        sessions.values.first { path.hasPrefix($0.tempDirectory.path) }
    }

    func sessionForArchive(at archiveURL: URL) -> ArchiveSession? {
        sessions[archiveURL.path]
    }

    func isInsideArchive(path: String) -> Bool {
        sessionForPath(path) != nil
    }

    // MARK: - Dirty Tracking

    func markDirty(archivePath: String) {
        if var session = sessions[archivePath] {
            session.isDirty = true
            sessions[archivePath] = session
            log.debug("[ArchiveManager] Marked dirty: \(URL(fileURLWithPath: archivePath).lastPathComponent)")
        }
    }

    func markDirtyByTempPath(_ tempPath: String) {
        for (key, var session) in sessions {
            if tempPath.hasPrefix(session.tempDirectory.path) {
                session.isDirty = true
                sessions[key] = session
                log.debug("[ArchiveManager] Marked dirty via temp: \(session.archiveURL.lastPathComponent)")
                return
            }
        }
    }

    func archiveURL(forTempPath tempPath: String) -> URL? {
        log.debug(#function + ": \(tempPath)")
        return sessionForPath(tempPath)?.archiveURL
    }

    // MARK: - Cleanup

    func cleanup() {
        log.debug(#function + ": \(sessions.count) sessions")
        for (_, session) in sessions {
            try? fm.removeItem(at: session.tempDirectory)
        }
        sessions.removeAll()
        try? fm.removeItem(at: baseTempDir)
    }

    // MARK: - Private: Dirty Check

    private func checkDirty(session: ArchiveSession) -> Bool {
        guard
            let enumerator = fm.enumerator(
                at: session.tempDirectory,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )
        else { return false }

        let baselineDate: Date
        if let attrs = try? fm.attributesOfItem(atPath: session.tempDirectory.path),
            let created = attrs[.creationDate] as? Date
        {
            baselineDate = created
        } else {
            return false
        }

        while let url = enumerator.nextObject() as? URL {
            if let vals = try? url.resourceValues(forKeys: [.contentModificationDateKey]),
                let modDate = vals.contentModificationDate,
                modDate > baselineDate
            {
                log.debug("[ArchiveManager] Dirty file detected: \(url.lastPathComponent)")
                return true
            }
        }
        return false
    }
}

enum ArchiveManagerError: LocalizedError, Sendable {
    case unsupportedFormat(String)
    case extractionFailed(String)
    case repackFailed(String)
    case toolNotFound(String)

    var errorDescription: String? {
        switch self {
            case .unsupportedFormat(let ext): return "Unsupported archive format: .\(ext)"
            case .extractionFailed(let msg): return "Archive extraction failed: \(msg)"
            case .repackFailed(let msg): return "Archive repacking failed: \(msg)"
            case .toolNotFound(let msg): return msg
        }
    }
}
