// ArchiveManager.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 11.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Central archive session coordinator — open, close, dirty tracking

import AppKit
import Foundation

// MARK: - Archive Manager
/// Central archive session coordinator with reference counting.
/// Supports same archive opened on multiple panels — tmp deleted only when all close.
actor ArchiveManager {

    static let shared = ArchiveManager()

    private var sessions: [String: ArchiveSession] = [:]
    /// Reference count per archive path — how many panels have it open
    private var refCounts: [String: Int] = [:]
    private var openingInProgress: Set<String> = []
    private let fm = FileManager.default

    private let baseTempDir: URL = {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("MiMiNavigator_archives", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    private init() {}

    // MARK: - Password Helpers
    private func storedArchivePassword() async -> String? {
        await MainActor.run {
            ArchivePasswordStore.shared.loadPassword()
        }
    }

    private func saveArchivePasswordIfNeeded(_ password: String?) async {
        guard let password, !password.isEmpty else { return }
        await MainActor.run {
            ArchivePasswordStore.shared.savePassword(password)
        }
    }

    private func promptArchivePassword(for archiveURL: URL, wrongPassword: Bool) async -> String? {
        await MainActor.run {
            let alert = NSAlert()
            alert.messageText = wrongPassword ? "Wrong Archive Password" : "Archive Password Required"
            alert.informativeText = wrongPassword
                ? "The password for \(archiveURL.lastPathComponent) is incorrect. Enter a new password to continue."
                : "\(archiveURL.lastPathComponent) is password-protected. Enter the password to continue."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Cancel")

            let input = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
            input.placeholderString = "Password…"
            alert.accessoryView = input

            let response = alert.runModal()
            guard response == .alertFirstButtonReturn else { return nil }

            let password = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            return password.isEmpty ? nil : password
        }
    }

    private func resetTempDirectory(_ tempDirectory: URL) throws {
        if fm.fileExists(atPath: tempDirectory.path) {
            try fm.removeItem(at: tempDirectory)
        }
        try fm.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    private func isPasswordProtectedFormat(_ format: ArchiveFormat) -> Bool {
        switch format {
        case .zip, .sevenZip, .sevenZipGeneric:
            return true
        default:
            return false
        }
    }

    private func extractArchive(
        archiveURL: URL,
        format: ArchiveFormat,
        to tempDir: URL,
        password: String?,
        onProgress: ArchiveExtractor.ProgressLine?,
        processHandle: ActiveArchiveProcess?
    ) async throws {
        try await ArchiveExtractor.extract(
            archiveURL: archiveURL,
            format: format,
            to: tempDir,
            password: password,
            onProgress: onProgress,
            processHandle: processHandle
        )
    }

    private func extractWithPasswordFlow(
        archiveURL: URL,
        format: ArchiveFormat,
        to tempDir: URL,
        explicitPassword: String?,
        onProgress: ArchiveExtractor.ProgressLine?,
        processHandle: ActiveArchiveProcess?
    ) async throws {
        let initialPassword: String?
        if let explicitPassword {
            initialPassword = explicitPassword
        } else if isPasswordProtectedFormat(format) {
            initialPassword = await storedArchivePassword()
        } else {
            initialPassword = nil
        }

        do {
            try await extractArchive(
                archiveURL: archiveURL,
                format: format,
                to: tempDir,
                password: initialPassword,
                onProgress: onProgress,
                processHandle: processHandle
            )
            await saveArchivePasswordIfNeeded(initialPassword)
            return
        } catch {
            guard let archiveError = error as? ArchiveManagerError,
                  archiveError.isPasswordRelated,
                  isPasswordProtectedFormat(format)
            else {
                throw error
            }
        }

        var attempt = 0
        var wrongPassword = true
        while attempt < 3 {
            attempt += 1
            let promptedPassword = await promptArchivePassword(for: archiveURL, wrongPassword: wrongPassword)
            guard let promptedPassword else {
                throw ArchiveManagerError.operationCancelled
            }

            do {
                try resetTempDirectory(tempDir)
                try await extractArchive(
                    archiveURL: archiveURL,
                    format: format,
                    to: tempDir,
                    password: promptedPassword,
                    onProgress: onProgress,
                    processHandle: processHandle
                )
                await saveArchivePasswordIfNeeded(promptedPassword)
                return
            } catch {
                if let archiveError = error as? ArchiveManagerError, archiveError.isPasswordRelated {
                    wrongPassword = true
                    continue
                }
                throw error
            }
        }

        throw ArchiveManagerError.wrongPassword
    }

    // MARK: - Open Helpers
    private func existingSessionDirectory(for key: String) -> URL? {
        guard let existing = sessions[key] else { return nil }
        refCounts[key, default: 1] += 1
        log.debug("[ArchiveManager] Reusing session for \(existing.archiveURL.lastPathComponent), refCount=\(refCounts[key] ?? 1)")
        return existing.tempDirectory
    }

    private func waitForOpeningSession(for key: String, archiveURL: URL) async throws -> URL {
        for _ in 0..<30 {
            try await Task.sleep(nanoseconds: 100_000_000)
            if let tempDirectory = sessions[key]?.tempDirectory {
                return tempDirectory
            }
        }
        throw ArchiveManagerError.extractionFailed("Timeout waiting for: \(archiveURL.lastPathComponent)")
    }

    private func detectFormat(for archiveURL: URL) throws -> ArchiveFormat {
        guard let format = ArchiveFormatDetector.detect(url: archiveURL) else {
            throw ArchiveManagerError.unsupportedFormat(archiveURL.pathExtension)
        }
        return format
    }

    private func makeTempDirectory() throws -> URL {
        let tempDirectory = baseTempDir.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        return tempDirectory
    }

    private func buildSession(for archiveURL: URL, format: ArchiveFormat, tempDir: URL) -> ArchiveSession {
        let attributes = (try? fm.attributesOfItem(atPath: archiveURL.path)) ?? [:]
        let snapshot = snapshotMtimes(in: tempDir)
        return ArchiveSession(
            archiveURL: archiveURL,
            tempDirectory: tempDir,
            format: format,
            isDirty: false,
            originalPosixPermissions: (attributes[.posixPermissions] as? NSNumber)?.int16Value ?? 0o644,
            originalModificationDate: attributes[.modificationDate] as? Date,
            originalCreationDate: attributes[.creationDate] as? Date,
            originalOwnerName: (attributes[.ownerAccountName] as? String) ?? "",
            baselineSnapshot: snapshot
        )
    }

    // MARK: - Open

    func openArchive(
        at archiveURL: URL,
        password: String? = nil,
        onProgress: ArchiveExtractor.ProgressLine? = nil,
        processHandle: ActiveArchiveProcess? = nil
    ) async throws -> URL {
        log.debug("[ArchiveManager] openArchive: \(archiveURL.lastPathComponent) hasPassword=\(password != nil) pwdLen=\(password?.count ?? 0)")
        let key = archiveURL.path
        if let tempDirectory = existingSessionDirectory(for: key) {
            return tempDirectory
        }
        if openingInProgress.contains(key) {
            return try await waitForOpeningSession(for: key, archiveURL: archiveURL)
        }
        openingInProgress.insert(key)
        defer { openingInProgress.remove(key) }
        let format = try detectFormat(for: archiveURL)
        let tempDir = try makeTempDirectory()
        do {
            try await extractWithPasswordFlow(
                archiveURL: archiveURL,
                format: format,
                to: tempDir,
                explicitPassword: password,
                onProgress: onProgress,
                processHandle: processHandle
            )
        } catch {
            log.error("[ArchiveManager] openArchive: Extraction failed: \(error)")
            try? fm.removeItem(at: tempDir)
            throw error
        }
        let session = buildSession(for: archiveURL, format: format, tempDir: tempDir)
        sessions[key] = session
        refCounts[key] = 1
        log.info("[ArchiveManager] Opened: \(archiveURL.lastPathComponent), refCount=1")
        return tempDir
    }

    // MARK: - Close

    /// Close archive session. Only removes tmp when refCount reaches 0.
    func closeArchive(at archiveURL: URL, repackIfDirty: Bool) async throws {
        let key = archiveURL.path
        guard let session = sessions[key] else { return }
        // Decrement reference count
        let currentRef = refCounts[key, default: 1]
        if currentRef > 1 {
            refCounts[key] = currentRef - 1
            log.info("[ArchiveManager] Close \(archiveURL.lastPathComponent), refCount=\(currentRef - 1) — keeping tmp")
            return  // Other panels still using this archive
        }
        // Last reference — actually close and cleanup
        log.info("[ArchiveManager] Close \(archiveURL.lastPathComponent), refCount=0 — removing tmp")
        defer {
            try? fm.removeItem(at: session.tempDirectory)
            sessions.removeValue(forKey: key)
            refCounts.removeValue(forKey: key)
        }
        if repackIfDirty {
            sessions[key]?.isDirty = session.isDirty || scanForChanges(in: session)
        }
        if (sessions[key]?.isDirty ?? false) && repackIfDirty {
            // Detect empty archive before repacking
            let contents = (try? fm.contentsOfDirectory(atPath: session.tempDirectory.path)) ?? []
            if contents.isEmpty {
                log.error("[ArchiveManager] Archive became empty after modifications: \(archiveURL.lastPathComponent)")
                throw ArchiveManagerError.extractionFailed("Archive is empty after modifications")
            }
            log.info("[ArchiveManager] Repacking: \(archiveURL.lastPathComponent)")
            try await ArchiveRepacker.repack(session: session)
        }
    }

    // MARK: - Dirty

    func markDirty(archivePath: String) {
        sessions[archivePath]?.isDirty = true
    }

    func markDirtyByTempPath(_ tempPath: String) {
        for (key, session) in sessions where tempPath.hasPrefix(session.tempDirectory.path) {
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
        for session in sessions.values {
            try? fm.removeItem(at: session.tempDirectory)
        }
        sessions.removeAll()
        refCounts.removeAll()
        openingInProgress.removeAll()
        try? fm.removeItem(at: baseTempDir)
    }

    // MARK: - Private
    /// Build a relative-path → mtime snapshot of every file in tempDir.
    private func snapshotMtimes(in tempDir: URL) -> [String: Date] {
        var snap: [String: Date] = [:]
        guard
            let enumerator = fm.enumerator(
                at: tempDir,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: .skipsHiddenFiles
            )
        else { return snap }

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
        guard
            let enumerator = fm.enumerator(
                at: session.tempDirectory,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: .skipsHiddenFiles
            )
        else { return false }
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
