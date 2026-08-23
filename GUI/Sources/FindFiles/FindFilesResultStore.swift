// FindFilesResultStore.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Actor-isolated persistence for saved Find Files results.

import Foundation

// MARK: - Find Files Result Store
actor FindFilesResultStore {
    static let shared = FindFilesResultStore()
    private let fileURL: URL

    private init() {
        let directory = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".mimi", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("search_results.json")
    }

    // MARK: - Save
    func save(_ payload: SavedSearchPayload) throws {
        let data = try JSONEncoder().encode(payload)
        try data.write(to: fileURL, options: .atomic)
    }

    // MARK: - Load
    func load() throws -> SavedSearchPayload? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        return try JSONDecoder().decode(SavedSearchPayload.self, from: Data(contentsOf: fileURL))
    }
}
