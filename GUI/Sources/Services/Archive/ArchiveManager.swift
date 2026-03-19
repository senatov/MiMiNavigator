    // ArchiveManager.swift
    // MiMiNavigator
    //
    // Created by Iakov Senatov on 11.02.2026.
    // Copyright © 2026 Senatov. All rights reserved.
    // Description: Central archive session coordinator — open, close, dirty tracking

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

        // MARK: - Open

        func openArchive(
            at archiveURL: URL,
            password: String? = nil,
            onProgress: ArchiveExtractor.ProgressLine? = nil,
            processHandle: ActiveArchiveProcess? = nil
        ) async throws -> URL {
            log.debug("[ArchiveManager] openArchive: \(archiveURL.lastPathComponent) hasPassword=\(password != nil) pwdLen=\(password?.count ?? 0)")
            let key = archiveURL.path

            if let existing = sessions[key] {
                refCounts[key, default: 1] += 1
                log.debug("[ArchiveManager] Reusing session for \(archiveURL.lastPathComponent), refCount=\(refCounts[key] ?? 1)")
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
                try await ArchiveExtractor.extract(
                    archiveURL: archiveURL, format: format, to: tempDir,
                    password: password, onProgress: onProgress, processHandle: processHandle
                )
            } catch {
                log.error("[ArchiveManager] openArchive: Extraction failed: \(error)")
                openingInProgress.remove(key)
                try? fm.removeItem(at: tempDir)
                throw error
            }

            // Snapshot mtime of every extracted file AFTER extraction completes.
            // scanForChanges() compares against this to detect real user edits.
            let snapshot = snapshotMtimes(in: tempDir)

            let session = ArchiveSession(
                archiveURL: archiveURL,
                tempDirectory: tempDir,
                format: format,
                isDirty: false,
                originalPosixPermissions: (attrs[.posixPermissions] as? NSNumber)?.int16Value ?? 0o644,
                originalModificationDate: attrs[.modificationDate] as? Date,
                originalCreationDate: attrs[.creationDate] as? Date,
                originalOwnerName: (attrs[.ownerAccountName] as? String) ?? "",
                baselineSnapshot: snapshot
            )

            sessions[key] = session
            refCounts[key] = 1  // First open — refCount = 1
            openingInProgress.remove(key)
            log.info("[ArchiveManager] Opened: \(archiveURL.lastPathComponent), refCount=1")
            return tempDir
        }

        // MARK: - Close

        /// Close archive session. Only removes tmp when refCount reaches 0.
        func closeArchive(at archiveURL: URL, repackIfDirty: Bool) async throws {
            let key = archiveURL.path
            guard var session = sessions[key] else { return }
            
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
                session.isDirty = session.isDirty || scanForChanges(in: session)
            }

            if session.isDirty && repackIfDirty {
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
            refCounts.removeAll()
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
