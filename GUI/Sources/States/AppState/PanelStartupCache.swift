// PanelStartupCache.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 27.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Persists panel file listings to disk so the app shows files instantly on launch
//   while the real directory scan runs in the background.
//
// Strategy:
//   1. On exit  → save displayedLeftFiles / displayedRightFiles + their paths to JSON
//   2. On start → load the cache, show it immediately (< 50ms)
//   3. Background scan completes → replace cache data with live data silently

import FileModelKit
import Foundation

// MARK: - Panel Startup Cache

final class PanelStartupCache: @unchecked Sendable {

    static let shared = PanelStartupCache()

    // MARK: - Cache file location

    private static let cacheURL: URL = {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".mimi", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("panel_startup_cache.json")
    }()

    // MARK: - Codable payload

    private struct CachePayload: Codable {
        let leftPath: String
        let rightPath: String
        let leftFiles: [CustomFile]
        let rightFiles: [CustomFile]
        let savedAt: Date
    }

    // MARK: - Save (called on app exit or panel change)

    /// Saves current panel file lists to disk.
    /// Only saves if both panels have content — avoids caching empty state on crash.
    func save(leftPath: String, rightPath: String,
              leftFiles: [CustomFile], rightFiles: [CustomFile]) {
        guard !leftFiles.isEmpty || !rightFiles.isEmpty else { return }
        let payload = CachePayload(
            leftPath: leftPath,
            rightPath: rightPath,
            leftFiles: leftFiles,
            rightFiles: rightFiles,
            savedAt: Date()
        )
        do {
            let data = try JSONEncoder().encode(payload)
            try data.write(to: Self.cacheURL, options: .atomic)
            log.info("[PanelStartupCache] saved L=\(leftFiles.count) R=\(rightFiles.count) files")
        } catch {
            log.warning("[PanelStartupCache] save failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Load (called at app start, before real scan)

    /// Loads the cached panel file lists from disk.
    /// Returns nil if the cache is missing, corrupt, stale (>24h), or paths don't match.
    func load(forLeftPath leftPath: String, rightPath: String) -> (left: [CustomFile], right: [CustomFile])? {
        guard FileManager.default.fileExists(atPath: Self.cacheURL.path) else { return nil }
        do {
            let data = try Data(contentsOf: Self.cacheURL)
            let payload = try JSONDecoder().decode(CachePayload.self, from: data)
            // Invalidate if paths changed since last save
            guard payload.leftPath == leftPath, payload.rightPath == rightPath else {
                log.info("[PanelStartupCache] paths changed — cache skipped")
                return nil
            }
            // Invalidate if older than 24h (directory may have changed significantly)
            let age = Date().timeIntervalSince(payload.savedAt)
            guard age < 86_400 else {
                log.info("[PanelStartupCache] cache is \(Int(age / 3600))h old — skipped")
                return nil
            }
            log.info("[PanelStartupCache] loaded L=\(payload.leftFiles.count) R=\(payload.rightFiles.count) files (age \(Int(age))s)")
            return (payload.leftFiles, payload.rightFiles)
        } catch {
            log.warning("[PanelStartupCache] load failed: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Invalidate

    /// Removes the cache file (e.g. after a path change that can't be detected automatically).
    func invalidate() {
        try? FileManager.default.removeItem(at: Self.cacheURL)
        log.info("[PanelStartupCache] invalidated")
    }

    private init() {}
}
