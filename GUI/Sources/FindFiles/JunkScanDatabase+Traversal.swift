// JunkScanDatabase+Traversal.swift
// MiMiNavigator
// Copyright © 2026 Senatov. All rights reserved.

import Foundation
import SQLite3

// MARK: - Persisted Directory Traversal
extension JunkScanDatabase {
    // MARK: - Begin or Resume
    func beginTraversal(root: URL) throws -> Int {
        guard let database else { throw JunkScanError.databaseFailure }
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(database, "SELECT visited FROM scan_state WHERE root = ? AND active = 1", -1, &statement, nil) == SQLITE_OK {
            bind(root.path, to: statement, at: 1)
            if sqlite3_step(statement) == SQLITE_ROW {
                let visited = Int(sqlite3_column_int(statement, 0))
                sqlite3_finalize(statement)
                return visited
            }
        }
        sqlite3_finalize(statement)
        guard sqlite3_exec(database, "BEGIN IMMEDIATE", nil, nil, nil) == SQLITE_OK else { throw JunkScanError.databaseFailure }
        var succeeded = true
        for table in ["scan_queue", "scan_files", "scan_directories", "scan_candidates", "scan_state"] {
            succeeded = execute("DELETE FROM \(table) WHERE root = ?", root.path) && succeeded
        }
        succeeded = execute("INSERT INTO scan_queue(root, path) VALUES (?, ?)", root.path, root.path) && succeeded
        succeeded = execute("INSERT INTO scan_state(root, active, visited) VALUES (?, 1, 0)", root.path) && succeeded
        guard succeeded, sqlite3_exec(database, "COMMIT", nil, nil, nil) == SQLITE_OK else {
            sqlite3_exec(database, "ROLLBACK", nil, nil, nil)
            throw JunkScanError.databaseFailure
        }
        return 0
    }

    // MARK: - Next Pending Directory
    func nextDirectory(root: URL) -> URL? {
        guard let database else { return nil }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, "SELECT path FROM scan_queue WHERE root = ? ORDER BY path LIMIT 1", -1, &statement, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(statement) }
        bind(root.path, to: statement, at: 1)
        guard sqlite3_step(statement) == SQLITE_ROW, let pointer = sqlite3_column_text(statement, 0) else { return nil }
        return URL(fileURLWithPath: String(cString: pointer), isDirectory: true)
    }

    // MARK: - Commit One Directory
    func saveDirectory(_ batch: JunkDirectoryBatch, root: URL) -> Bool {
        guard let database, sqlite3_exec(database, "BEGIN IMMEDIATE", nil, nil, nil) == SQLITE_OK else { return false }
        var succeeded = true
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(database, "INSERT OR REPLACE INTO scan_files(root, path, size, modified) VALUES (?, ?, ?, ?)", -1, &statement, nil) == SQLITE_OK {
            for file in batch.files {
                sqlite3_reset(statement)
                sqlite3_clear_bindings(statement)
                bind(root.path, to: statement, at: 1)
                bind(file.url.path, to: statement, at: 2)
                sqlite3_bind_int64(statement, 3, file.size)
                sqlite3_bind_double(statement, 4, file.modified.timeIntervalSince1970)
                if sqlite3_step(statement) != SQLITE_DONE { succeeded = false; break }
            }
        } else { succeeded = false }
        sqlite3_finalize(statement)
        statement = nil
        if succeeded { succeeded = insertPaths(batch.childDirectories, root: root, table: "scan_queue") }
        if succeeded { succeeded = insertPaths(batch.childDirectories, root: root, table: "scan_directories") }
        if succeeded, sqlite3_prepare_v2(database, "INSERT OR REPLACE INTO scan_candidates(root, path, payload) VALUES (?, ?, ?)", -1, &statement, nil) == SQLITE_OK {
            for candidate in batch.candidates {
                guard let payload = try? JSONEncoder().encode(candidate) else { succeeded = false; break }
                sqlite3_reset(statement)
                sqlite3_clear_bindings(statement)
                bind(root.path, to: statement, at: 1)
                bind(candidate.id, to: statement, at: 2)
                _ = payload.withUnsafeBytes { bytes in
                    sqlite3_bind_blob(statement, 3, bytes.baseAddress, Int32(bytes.count), transient)
                }
                if sqlite3_step(statement) != SQLITE_DONE { succeeded = false; break }
            }
        } else if succeeded { succeeded = false }
        sqlite3_finalize(statement)
        if succeeded { succeeded = execute("DELETE FROM scan_queue WHERE root = ? AND path = ?", root.path, batch.directory.path) }
        if succeeded { succeeded = execute("UPDATE scan_state SET visited = visited + \(batch.visited) WHERE root = ?", root.path) }
        sqlite3_exec(database, succeeded ? "COMMIT" : "ROLLBACK", nil, nil, nil)
        return succeeded
    }

    // MARK: - Read Persisted Records
    func traversalData(root: URL) -> (files: [JunkFileRecord], directories: [URL], candidates: [JunkCandidate]) {
        guard let database else { return ([], [], []) }
        var files: [JunkFileRecord] = []
        var directories: [URL] = []
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(database, "SELECT path, size, modified FROM scan_files WHERE root = ?", -1, &statement, nil) == SQLITE_OK {
            bind(root.path, to: statement, at: 1)
            while sqlite3_step(statement) == SQLITE_ROW {
                guard let pointer = sqlite3_column_text(statement, 0) else { continue }
                files.append(JunkFileRecord(url: URL(fileURLWithPath: String(cString: pointer)), size: sqlite3_column_int64(statement, 1), modified: Date(timeIntervalSince1970: sqlite3_column_double(statement, 2))))
            }
        }
        sqlite3_finalize(statement)
        statement = nil
        if sqlite3_prepare_v2(database, "SELECT path FROM scan_directories WHERE root = ?", -1, &statement, nil) == SQLITE_OK {
            bind(root.path, to: statement, at: 1)
            while sqlite3_step(statement) == SQLITE_ROW {
                guard let pointer = sqlite3_column_text(statement, 0) else { continue }
                directories.append(URL(fileURLWithPath: String(cString: pointer), isDirectory: true))
            }
        }
        sqlite3_finalize(statement)
        return (files, directories, traversalCandidates(root: root))
    }

    // MARK: - Read Partial Candidates
    func traversalCandidates(root: URL) -> [JunkCandidate] {
        guard let database else { return [] }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, "SELECT payload FROM scan_candidates WHERE root = ?", -1, &statement, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(statement) }
        bind(root.path, to: statement, at: 1)
        var candidates: [JunkCandidate] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let pointer = sqlite3_column_blob(statement, 0) else { continue }
            let data = Data(bytes: pointer, count: Int(sqlite3_column_bytes(statement, 0)))
            if let candidate = try? JSONDecoder().decode(JunkCandidate.self, from: data) { candidates.append(candidate) }
        }
        return candidates
    }

    // MARK: - Complete Traversal
    func finishTraversal(root: URL) throws {
        guard let database, sqlite3_exec(database, "BEGIN IMMEDIATE", nil, nil, nil) == SQLITE_OK else { throw JunkScanError.databaseFailure }
        var succeeded = execute("UPDATE scan_state SET active = 0 WHERE root = ?", root.path)
        succeeded = execute("DELETE FROM file_index WHERE root = ?", root.path) && succeeded
        succeeded = execute("INSERT INTO file_index(path, root, size, modified) SELECT path, root, size, modified FROM scan_files WHERE root = ?", root.path) && succeeded
        for table in ["scan_queue", "scan_files", "scan_directories", "scan_candidates"] {
            succeeded = execute("DELETE FROM \(table) WHERE root = ?", root.path) && succeeded
        }
        guard succeeded, sqlite3_exec(database, "COMMIT", nil, nil, nil) == SQLITE_OK else {
            sqlite3_exec(database, "ROLLBACK", nil, nil, nil)
            throw JunkScanError.databaseFailure
        }
    }

    // MARK: - Insert Path Rows
    private func insertPaths(_ paths: [URL], root: URL, table: String) -> Bool {
        guard let database else { return false }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, "INSERT OR IGNORE INTO \(table)(root, path) VALUES (?, ?)", -1, &statement, nil) == SQLITE_OK else { return false }
        defer { sqlite3_finalize(statement) }
        for path in paths {
            sqlite3_reset(statement)
            sqlite3_clear_bindings(statement)
            bind(root.path, to: statement, at: 1)
            bind(path.path, to: statement, at: 2)
            if sqlite3_step(statement) != SQLITE_DONE { return false }
        }
        return true
    }

    // MARK: - Execute Bound SQL
    private func execute(_ sql: String, _ values: String...) -> Bool {
        guard let database else { return false }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else { return false }
        defer { sqlite3_finalize(statement) }
        for (index, value) in values.enumerated() { bind(value, to: statement, at: Int32(index + 1)) }
        return sqlite3_step(statement) == SQLITE_DONE
    }
}
