// GoogleDriveTokenConfigStore.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Local Google Drive OAuth token cache persisted under ~/.mimi.

import Foundation

// MARK: - GoogleDriveTokenConfigStore

enum GoogleDriveTokenConfigStore {
    private static let cachePath = "~/.mimi/google_drive_token_cache.json"

    // MARK: - Cache URL

    private static var cacheURL: URL {
        URL(fileURLWithPath: NSString(string: cachePath).expandingTildeInPath)
    }

    // MARK: - Load

    static func load() throws -> GoogleDriveTokenCache? {
        let url = cacheURL
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(GoogleDriveTokenCache.self, from: data)
    }

    // MARK: - Save

    static func save(_ cache: GoogleDriveTokenCache) throws {
        let url = cacheURL
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(cache)
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    // MARK: - Delete

    static func delete() {
        try? FileManager.default.removeItem(at: cacheURL)
    }
}
