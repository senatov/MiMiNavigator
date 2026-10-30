// JunkScanDatabase.swift
// MiMiNavigator
// Copyright © 2026 Senatov. All rights reserved.

import Foundation
import SQLite3

// MARK: - Cleanup SQLite Cache
actor JunkScanDatabase {
    static let shared = JunkScanDatabase()
    private var database: OpaquePointer?
    private let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    // MARK: - Open Database
    private init() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MiMiNavigator", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let path = directory.appendingPathComponent("Cleanup.sqlite").path
        guard sqlite3_open(path, &database) == SQLITE_OK else {
            log.error("[Cleanup] Cannot open SQLite cache")
            return
        }
        sqlite3_exec(database, "PRAGMA journal_mode=WAL", nil, nil, nil)
        sqlite3_exec(database, "CREATE TABLE IF NOT EXISTS hashes (path TEXT PRIMARY KEY, size INTEGER NOT NULL, modified REAL NOT NULL, digest TEXT NOT NULL, seen REAL NOT NULL)", nil, nil, nil)
        sqlite3_exec(database, "CREATE TABLE IF NOT EXISTS snapshots (root TEXT PRIMARY KEY, payload BLOB NOT NULL, saved REAL NOT NULL)", nil, nil, nil)
    }

    // MARK: - Cached Digest
    func digest(for url: URL, size: Int64, modified: Date) -> String? {
        guard let database else { return nil }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, "SELECT digest FROM hashes WHERE path = ? AND size = ? AND modified = ?", -1, &statement, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(statement) }
        bind(url.path, to: statement, at: 1)
        sqlite3_bind_int64(statement, 2, size)
        sqlite3_bind_double(statement, 3, modified.timeIntervalSince1970)
        guard sqlite3_step(statement) == SQLITE_ROW, let pointer = sqlite3_column_text(statement, 0) else { return nil }
        return String(cString: pointer)
    }

    // MARK: - Save Digest
    func saveDigest(_ digest: String, for url: URL, size: Int64, modified: Date) {
        guard let database else { return }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, "INSERT OR REPLACE INTO hashes (path, size, modified, digest, seen) VALUES (?, ?, ?, ?, ?)", -1, &statement, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(statement) }
        bind(url.path, to: statement, at: 1)
        sqlite3_bind_int64(statement, 2, size)
        sqlite3_bind_double(statement, 3, modified.timeIntervalSince1970)
        bind(digest, to: statement, at: 4)
        sqlite3_bind_double(statement, 5, Date().timeIntervalSince1970)
        sqlite3_step(statement)
    }

    // MARK: - Save Candidates
    func saveSnapshot(_ candidates: [JunkCandidate], root: URL) {
        guard let database, let payload = try? JSONEncoder().encode(candidates) else { return }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, "INSERT OR REPLACE INTO snapshots (root, payload, saved) VALUES (?, ?, ?)", -1, &statement, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(statement) }
        bind(root.path, to: statement, at: 1)
        _ = payload.withUnsafeBytes { bytes in
            sqlite3_bind_blob(statement, 2, bytes.baseAddress, Int32(bytes.count), transient)
        }
        sqlite3_bind_double(statement, 3, Date().timeIntervalSince1970)
        sqlite3_step(statement)
        sqlite3_exec(database, "DELETE FROM hashes WHERE seen < strftime('%s','now') - 2592000", nil, nil, nil)
    }

    // MARK: - Load Candidates
    func loadSnapshot(root: URL) -> [JunkCandidate] {
        guard let database else { return [] }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, "SELECT payload FROM snapshots WHERE root = ?", -1, &statement, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(statement) }
        bind(root.path, to: statement, at: 1)
        guard sqlite3_step(statement) == SQLITE_ROW, let pointer = sqlite3_column_blob(statement, 0) else { return [] }
        let payload = Data(bytes: pointer, count: Int(sqlite3_column_bytes(statement, 0)))
        let decoded = (try? JSONDecoder().decode([JunkCandidate].self, from: payload)) ?? []
        return decoded.filter { candidate in
            let path = candidate.url.standardizedFileURL.path
            return path.hasPrefix(root.path + "/") && !JunkScanEngine.shouldExclude(path) && FileManager.default.fileExists(atPath: path)
        }
    }

    // MARK: - Bind Text
    private func bind(_ value: String, to statement: OpaquePointer?, at index: Int32) {
        _ = value.withCString { sqlite3_bind_text(statement, index, $0, -1, transient) }
    }
}
