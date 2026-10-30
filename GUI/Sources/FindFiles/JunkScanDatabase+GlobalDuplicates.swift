// JunkScanDatabase+GlobalDuplicates.swift
// MiMiNavigator
// Copyright © 2026 Senatov. All rights reserved.

import Foundation
import SQLite3

// MARK: - Cross-Volume Duplicate Index
extension JunkScanDatabase {
    // MARK: - Same-Size Records
    func globalDuplicateRecords() -> [JunkFileRecord] {
        guard let database else { return [] }
        let sql = "SELECT path, size, modified FROM file_index WHERE size > 0 AND size IN (SELECT size FROM file_index WHERE size > 0 GROUP BY size HAVING COUNT(*) > 1)"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(statement) }
        var records: [JunkFileRecord] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let pointer = sqlite3_column_text(statement, 0) else { continue }
            records.append(JunkFileRecord(url: URL(fileURLWithPath: String(cString: pointer)), size: sqlite3_column_int64(statement, 1), modified: Date(timeIntervalSince1970: sqlite3_column_double(statement, 2))))
        }
        return records
    }

    // MARK: - Persist Global Groups
    func saveGlobalCandidates(_ candidates: [JunkCandidate]) {
        guard let database, let payload = try? JSONEncoder().encode(candidates) else { return }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, "INSERT OR REPLACE INTO global_candidates(id, payload) VALUES (1, ?)", -1, &statement, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(statement) }
        _ = payload.withUnsafeBytes { bytes in
            sqlite3_bind_blob(statement, 1, bytes.baseAddress, Int32(bytes.count), transient)
        }
        sqlite3_step(statement)
    }

    // MARK: - Restore Global Groups
    func loadGlobalCandidates() -> [JunkCandidate] {
        guard let database else { return [] }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, "SELECT payload FROM global_candidates WHERE id = 1", -1, &statement, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW, let pointer = sqlite3_column_blob(statement, 0) else { return [] }
        let payload = Data(bytes: pointer, count: Int(sqlite3_column_bytes(statement, 0)))
        return ((try? JSONDecoder().decode([JunkCandidate].self, from: payload)) ?? []).filter { candidate in
            JunkScanScope.roots().contains { candidate.url.path.hasPrefix($0.path + "/") }
                && !JunkScanEngine.shouldExclude(candidate.url.path)
                && FileManager.default.fileExists(atPath: candidate.url.path)
        }
    }
}
