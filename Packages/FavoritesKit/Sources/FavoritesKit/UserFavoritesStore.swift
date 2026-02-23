// UserFavoritesStore.swift
// FavoritesKit
//
// Created by Iakov Senatov on 22.02.2026.
// Refactored: 23.02.2026 — os.Logger replaces print(); import LogKit
// Copyright © 2026 Senatov. All rights reserved.
// Description: Persistent store for user-added favorites (local paths + network shares).
//   Stored in UserDefaults as JSON. @Observable for SwiftUI live updates.
//   Supports local directories and network share URLs (smb://, afp://, sftp://, etc.).

import Foundation
import LogKit
import Observation

// MARK: - UserFavoriteEntry
/// A single user-added favorite — local path OR network share URL
public struct UserFavoriteEntry: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public let name: String      // display name (last path component or share name)
    public let path: String      // /Users/senat/Documents OR smb://server/share

    public var isNetworkShare: Bool {
        path.hasPrefix("smb://") || path.hasPrefix("afp://") ||
        path.hasPrefix("nfs://") || path.hasPrefix("ftp://") ||
        path.hasPrefix("sftp://")
    }

    public var displayIcon: String {
        if isNetworkShare { return "server.rack" }
        let p = path.lowercased()
        if p.contains("/desktop")     { return "desktopcomputer" }
        if p.contains("/documents")   { return "doc.text.fill" }
        if p.contains("/downloads")   { return "arrow.down.circle.fill" }
        if p.contains("/pictures")    { return "photo.fill" }
        if p.contains("/music")       { return "music.note" }
        if p.contains("/movies")      { return "film.fill" }
        if p.contains("/develop") || p.contains("/projects") { return "hammer.fill" }
        return "folder.fill"
    }

    // MARK: -
    public init(name: String, path: String) {
        self.id   = UUID()
        self.name = name
        self.path = path
    }
}

// MARK: - UserFavoritesStore
/// Shared observable store — read/write from any SwiftUI view or context menu
@Observable
@MainActor
public final class UserFavoritesStore {

    public static let shared = UserFavoritesStore()

    // MARK: - Published state
    public private(set) var entries: [UserFavoriteEntry] = []

    // MARK: - Persistence key
    private let defaultsKey = "MiMiNavigator.UserFavorites.v1"

    // MARK: -
    private init() {
        load()
    }

    // MARK: - Add
    /// Add a local directory path or network share URL to favorites.
    /// Silently ignores duplicates (same path).
    public func add(path: String, name: String? = nil) {
        guard !path.isEmpty else { return }
        guard !entries.contains(where: { $0.path == path }) else {
            log.debug("[UserFavorites] already exists: \(path)")
            return
        }
        let displayName = name ?? URL(string: path)?.lastPathComponent
            ?? (path as NSString).lastPathComponent
        let entry = UserFavoriteEntry(name: displayName.isEmpty ? path : displayName, path: path)
        entries.append(entry)
        save()
        log.info("[UserFavorites] added '\(entry.name)' → \(path)")
    }

    // MARK: - Remove
    public func remove(id: UUID) {
        entries.removeAll { $0.id == id }
        save()
        log.debug("[UserFavorites] removed id=\(id)")
    }

    // MARK: - Remove by path
    public func remove(path: String) {
        entries.removeAll { $0.path == path }
        save()
    }

    // MARK: - Contains
    public func contains(path: String) -> Bool {
        entries.contains { $0.path == path }
    }

    // MARK: - Persistence
    private func save() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([UserFavoriteEntry].self, from: data)
        else { return }
        entries = decoded
        log.info("[UserFavorites] loaded \(self.entries.count) user favorites")
    }
}
