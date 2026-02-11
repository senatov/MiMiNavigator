// ArchiveManager.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 11.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Central archive management — extract to temp dir, track modifications, repack on exit

import Foundation

// MARK: - Archive Session
/// Tracks state of a single opened archive
struct ArchiveSession: Sendable {
    let archiveURL: URL
    let tempDirectory: URL
    let format: ArchiveFormat
    var isDirty: Bool = false

    /// Original POSIX permissions of the archive file
    let originalPosixPermissions: Int16
    /// Original modification date
    let originalModificationDate: Date?
    /// Original owner
    let originalOwnerName: String
}

// MARK: - Archive Manager
/// Actor managing archive extraction, temp directory lifecycle, dirty tracking, and repacking.
/// Archives are extracted to /tmp/MiMiNavigator_archives/<UUID>/ for read-write access.
/// On navigate-out, dirty archives are repacked preserving original attributes.
actor ArchiveManager {

    static let shared = ArchiveManager()

    // MARK: - State

    /// Maps archive absolute path → active session
    private var sessions: [String: ArchiveSession] = [:]

    /// Base temp directory for all archive extractions
    private let baseTempDir: URL = {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("MiMiNavigator_archives", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }()

    private let fm = FileManager.default

    private init() {}

    // MARK: - Open Archive

    /// Extracts archive to a temp directory and returns the path to navigate into.
    /// If already open, returns existing temp dir.
    func openArchive(at archiveURL: URL) async throws -> URL {
        let key = archiveURL.path

        // Already open? Return existing temp dir
        if let existing = sessions[key] {
            log.info("[ArchiveManager] Archive already open: \(archiveURL.lastPathComponent) → \(existing.tempDirectory.path)")
            return existing.tempDirectory
        }

        // Detect format
        guard let format = detectFormat(url: archiveURL) else {
            throw ArchiveManagerError.unsupportedFormat(archiveURL.pathExtension)
        }

        // Create unique temp directory
        let sessionID = UUID().uuidString
        let tempDir = baseTempDir.appendingPathComponent(sessionID, isDirectory: true)
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)

        log.info("[ArchiveManager] Extracting \(archiveURL.lastPathComponent) → \(tempDir.path)")

        // Snapshot original attributes before extraction
        let attrs = try fm.attributesOfItem(atPath: archiveURL.path)
        let permissions = (attrs[.posixPermissions] as? NSNumber)?.int16Value ?? 0o644
        let modDate = attrs[.modificationDate] as? Date
        let owner = (attrs[.ownerAccountName] as? String) ?? ""

        // Extract
        try await extractArchive(archiveURL: archiveURL, format: format, to: tempDir)

        // Create session
        let session = ArchiveSession(
            archiveURL: archiveURL,
            tempDirectory: tempDir,
            format: format,
            isDirty: false,
            originalPosixPermissions: permissions,
            originalModificationDate: modDate,
            originalOwnerName: owner
        )
        sessions[key] = session

        log.info("[ArchiveManager] Archive opened successfully: \(archiveURL.lastPathComponent)")
        return tempDir
    }

    // MARK: - Close Archive

    /// Closes an archive session. If dirty, repacks before cleanup.
    func closeArchive(at archiveURL: URL, repackIfDirty: Bool = true) async throws {
        let key = archiveURL.path
        guard var session = sessions[key] else {
            log.warning("[ArchiveManager] No open session for: \(archiveURL.lastPathComponent)")
            return
        }

        // Check if any files were modified in temp dir
        if repackIfDirty {
            let dirtyCheck = await checkDirty(session: session)
            session.isDirty = session.isDirty || dirtyCheck
        }

        if session.isDirty && repackIfDirty {
            log.info("[ArchiveManager] Repacking dirty archive: \(archiveURL.lastPathComponent)")
            try await repackArchive(session: session)
        }

        // Cleanup temp directory
        try? fm.removeItem(at: session.tempDirectory)
        sessions.removeValue(forKey: key)

        log.info("[ArchiveManager] Archive closed: \(archiveURL.lastPathComponent)")
    }

    // MARK: - Query State

    /// Returns the session if the given path is inside an extracted archive temp dir
    func sessionForPath(_ path: String) -> ArchiveSession? {
        for (_, session) in sessions {
            if path.hasPrefix(session.tempDirectory.path) {
                return session
            }
        }
        return nil
    }

    /// Returns the session for a specific archive URL
    func sessionForArchive(at archiveURL: URL) -> ArchiveSession? {
        sessions[archiveURL.path]
    }

    /// Check if a path is inside any extracted archive
    func isInsideArchive(path: String) -> Bool {
        sessionForPath(path) != nil
    }

    /// Mark an archive as dirty (files were modified)
    func markDirty(archivePath: String) {
        if var session = sessions[archivePath] {
            session.isDirty = true
            sessions[archivePath] = session
            log.debug("[ArchiveManager] Marked dirty: \(URL(fileURLWithPath: archivePath).lastPathComponent)")
        }
    }

    /// Mark dirty by temp directory path
    func markDirtyByTempPath(_ tempPath: String) {
        for (key, var session) in sessions {
            if tempPath.hasPrefix(session.tempDirectory.path) {
                session.isDirty = true
                sessions[key] = session
                log.debug("[ArchiveManager] Marked dirty via temp path: \(session.archiveURL.lastPathComponent)")
                return
            }
        }
    }

    /// Get the original archive URL for a temp directory path
    func archiveURL(forTempPath tempPath: String) -> URL? {
        sessionForPath(tempPath)?.archiveURL
    }

    /// Cleanup all temp directories (call on app exit)
    func cleanup() {
        log.info("[ArchiveManager] Cleaning up all \(sessions.count) archive sessions")
        for (_, session) in sessions {
            try? fm.removeItem(at: session.tempDirectory)
        }
        sessions.removeAll()
        try? fm.removeItem(at: baseTempDir)
    }

    // MARK: - Private: Format Detection

    private func detectFormat(url: URL) -> ArchiveFormat? {
        let ext = url.pathExtension.lowercased()
        let name = url.lastPathComponent.lowercased()

        if name.hasSuffix(".tar.gz") || ext == "tgz" { return .tarGz }
        if name.hasSuffix(".tar.bz2") { return .tarBz2 }

        switch ext {
        case "zip": return .zip
        case "tar": return .tar
        case "gz": return .tarGz
        case "bz2": return .tarBz2
        case "7z": return .sevenZip
        default: return nil
        }
    }

    // MARK: - Private: Extract

    private func extractArchive(archiveURL: URL, format: ArchiveFormat, to destination: URL) async throws {
        switch format {
        case .zip:
            try await extractZip(archiveURL: archiveURL, to: destination)
        case .tar, .tarGz, .tarBz2:
            try await extractTar(archiveURL: archiveURL, format: format, to: destination)
        case .sevenZip:
            try await extract7z(archiveURL: archiveURL, to: destination)
        }
    }

    private func extractZip(archiveURL: URL, to destination: URL) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-o", archiveURL.path, "-d", destination.path]
        process.standardOutput = Pipe()
        let errorPipe = Pipe()
        process.standardError = errorPipe
        try await runProcess(process, errorPipe: errorPipe)
    }

    private func extractTar(archiveURL: URL, format: ArchiveFormat, to destination: URL) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        var args = ["-x"]
        switch format {
        case .tarGz: args.append("-z")
        case .tarBz2: args.append("-j")
        default: break
        }
        args.append(contentsOf: ["-f", archiveURL.path, "-C", destination.path])
        process.arguments = args
        process.standardOutput = Pipe()
        let errorPipe = Pipe()
        process.standardError = errorPipe
        try await runProcess(process, errorPipe: errorPipe)
    }

    private func extract7z(archiveURL: URL, to destination: URL) async throws {
        let szPaths = ["/opt/homebrew/bin/7z", "/usr/local/bin/7z", "/usr/bin/7z"]
        guard let szPath = szPaths.first(where: { fm.fileExists(atPath: $0) }) else {
            throw ArchiveManagerError.toolNotFound("7z not installed. Install with: brew install p7zip")
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: szPath)
        process.arguments = ["x", archiveURL.path, "-o\(destination.path)", "-y"]
        process.standardOutput = Pipe()
        let errorPipe = Pipe()
        process.standardError = errorPipe
        try await runProcess(process, errorPipe: errorPipe)
    }

    // MARK: - Private: Repack

    private func repackArchive(session: ArchiveSession) async throws {
        let archiveURL = session.archiveURL
        let tempDir = session.tempDirectory

        // Create backup of original archive
        let backupURL = archiveURL.deletingPathExtension()
            .appendingPathExtension("backup_\(Int(Date().timeIntervalSince1970))")
            .appendingPathExtension(archiveURL.pathExtension)
        try? fm.copyItem(at: archiveURL, to: backupURL)

        // Remove original archive
        try fm.removeItem(at: archiveURL)

        // List files in temp directory
        let contents = try fm.contentsOfDirectory(
            at: tempDir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )

        // Repack based on format
        switch session.format {
        case .zip:
            try await repackZip(files: contents, to: archiveURL, workDir: tempDir)
        case .tar, .tarGz, .tarBz2:
            try await repackTar(files: contents, to: archiveURL, format: session.format, workDir: tempDir)
        case .sevenZip:
            try await repack7z(files: contents, to: archiveURL, workDir: tempDir)
        }

        // Restore original attributes
        var attrs: [FileAttributeKey: Any] = [:]
        attrs[.posixPermissions] = NSNumber(value: session.originalPosixPermissions)
        if let modDate = session.originalModificationDate {
            attrs[.modificationDate] = modDate
        }
        try? fm.setAttributes(attrs, ofItemAtPath: archiveURL.path)

        // Remove backup on success
        try? fm.removeItem(at: backupURL)
        log.info("[ArchiveManager] Repacked successfully: \(archiveURL.lastPathComponent)")
    }

    private func repackZip(files: [URL], to archiveURL: URL, workDir: URL) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.currentDirectoryURL = workDir
        var args = ["-r", archiveURL.path]
        args.append(contentsOf: files.map { $0.lastPathComponent })
        process.arguments = args
        process.standardOutput = Pipe()
        let errorPipe = Pipe()
        process.standardError = errorPipe
        try await runProcess(process, errorPipe: errorPipe)
    }

    private func repackTar(files: [URL], to archiveURL: URL, format: ArchiveFormat, workDir: URL) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        process.currentDirectoryURL = workDir
        var args = ["-c"]
        switch format {
        case .tarGz: args.append("-z")
        case .tarBz2: args.append("-j")
        default: break
        }
        args.append(contentsOf: ["-f", archiveURL.path])
        args.append(contentsOf: files.map { $0.lastPathComponent })
        process.arguments = args
        process.standardOutput = Pipe()
        let errorPipe = Pipe()
        process.standardError = errorPipe
        try await runProcess(process, errorPipe: errorPipe)
    }

    private func repack7z(files: [URL], to archiveURL: URL, workDir: URL) async throws {
        let szPaths = ["/opt/homebrew/bin/7z", "/usr/local/bin/7z", "/usr/bin/7z"]
        guard let szPath = szPaths.first(where: { fm.fileExists(atPath: $0) }) else {
            throw ArchiveManagerError.toolNotFound("7z not available for repacking")
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: szPath)
        process.currentDirectoryURL = workDir
        var args = ["a", archiveURL.path]
        args.append(contentsOf: files.map { $0.lastPathComponent })
        process.arguments = args
        process.standardOutput = Pipe()
        let errorPipe = Pipe()
        process.standardError = errorPipe
        try await runProcess(process, errorPipe: errorPipe)
    }

    // MARK: - Private: Dirty Check

    private func checkDirty(session: ArchiveSession) async -> Bool {
        let tempDir = session.tempDirectory
        guard let enumerator = fm.enumerator(
            at: tempDir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return false }

        let baselineDate: Date
        if let attrs = try? fm.attributesOfItem(atPath: tempDir.path),
           let created = attrs[.creationDate] as? Date {
            baselineDate = created
        } else {
            return false
        }

        while let url = enumerator.nextObject() as? URL {
            if let vals = try? url.resourceValues(forKeys: [.contentModificationDateKey]),
               let modDate = vals.contentModificationDate,
               modDate > baselineDate {
                return true
            }
        }
        return false
    }

    // MARK: - Private: Process Runner

    private func runProcess(_ process: Process, errorPipe: Pipe) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            process.terminationHandler = { proc in
                if proc.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorMessage = String(data: errorData, encoding: .utf8) ?? "Exit code \(proc.terminationStatus)"
                    continuation.resume(throwing: ArchiveManagerError.extractionFailed(errorMessage))
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

// MARK: - Errors

enum ArchiveManagerError: LocalizedError, Sendable {
    case unsupportedFormat(String)
    case extractionFailed(String)
    case repackFailed(String)
    case toolNotFound(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let ext):
            return "Unsupported archive format: .\(ext)"
        case .extractionFailed(let msg):
            return "Archive extraction failed: \(msg)"
        case .repackFailed(let msg):
            return "Archive repacking failed: \(msg)"
        case .toolNotFound(let msg):
            return msg
        }
    }
}
