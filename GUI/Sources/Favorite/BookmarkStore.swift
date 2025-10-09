//
//  BookmarkStore.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 09.10.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import AppKit
import SwiftUI

// MARK: - Security-Scoped Bookmarks Helpers (Sandbox-Friendly)

/// Simple bookmark store backed by UserDefaults. In production, replace with your DB.
actor BookmarkStore {
    static let shared = BookmarkStore()
    private let defaults = UserDefaults.standard
    private let key = "FavoritesBookmarks.v1"

    /// Saves bookmark data for a path. Path is used as a key.
    func saveBookmark(for path: String, data: Data) {
        var dict = (defaults.dictionary(forKey: key) as? [String: Data]) ?? [:]
        dict[path] = data
        defaults.set(dict, forKey: key)
        log.debug("BookmarkStore: saved bookmark for \(path)")
    }

    // periphery:ignore
    /// Loads bookmark data by path.
    func loadBookmark(for path: String) -> Data? {
        let dict = (defaults.dictionary(forKey: key) as? [String: Data])
        return dict?[path]
    }

    // periphery:ignore
    /// Returns all stored bookmarks (path -> data).
    func all() -> [String: Data] {
        (defaults.dictionary(forKey: key) as? [String: Data]) ?? [:]
    }

    // periphery:ignore
    /// Removes a bookmark for the provided path.
    func remove(path: String) {
        var dict = (defaults.dictionary(forKey: key) as? [String: Data]) ?? [:]
        dict.removeValue(forKey: path)
        defaults.set(dict, forKey: key)
        log.debug("BookmarkStore: removed bookmark for \(path)")
    }
}

/// Presents an NSOpenPanel to grant access to a volume or folder and returns a security-scoped bookmark.
@MainActor
func grantAccessToVolumeAndSaveBookmark(
    startingAt url: URL = URL(fileURLWithPath: "/Volumes"),
    allowsMultiple: Bool = false
) async throws -> Data {
    let panel = NSOpenPanel()
    panel.title = "Allow access to a volume"
    panel.message = "This is necessary to access mounted system volumes and favorites."
    panel.directoryURL = url
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = allowsMultiple
    panel.canCreateDirectories = false
    panel.showsHiddenFiles = false
    panel.prompt = "Allow"
    panel.treatsFilePackagesAsDirectories = true

    let response = panel.runModal()
    guard response == .OK, let picked = panel.urls.first else {
        log.warning("User cancelled volume access panel")
        throw NSError(domain: "FavAccess", code: 1, userInfo: [NSLocalizedDescriptionKey: "User cancelled"])
    }

    do {
        let bookmark = try picked.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil)
        await BookmarkStore.shared.saveBookmark(for: picked.path, data: bookmark)
        log.info("Saved security-scoped bookmark for: \(picked.path)")
        return bookmark
    } catch {
        log.error("Failed to create bookmark: \(error.localizedDescription)")
        throw error
    }
}

// periphery:ignore
/// Resolves a stored security-scoped bookmark and runs the work block while access is active.
func withBookmarkAccess<T>(_ bookmark: Data, _ work: (URL) throws -> T) throws -> T {
    var isStale = false
    let url = try URL(
        resolvingBookmarkData: bookmark,
        options: [.withSecurityScope, .withoutUI],
        relativeTo: nil,
        bookmarkDataIsStale: &isStale)
    guard url.startAccessingSecurityScopedResource() else {
        log.error("Could not start security-scoped access for \(url.path)")
        throw NSError(domain: "FavAccess", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cannot start access"])
    }
    defer { url.stopAccessingSecurityScopedResource() }
    if isStale {
        log.warning("Bookmark is stale for \(url.path) — consider re-creating it")
    }
    return try work(url)
}

// periphery:ignore
/// Presents NSOpenPanel as a sheet attached to a specific window and returns saved bookmark data.
@MainActor
func presentAccessPanelAsSheet(
    startingAt url: URL = URL(fileURLWithPath: "/Volumes"),
    anchorWindow: NSWindow?
) async throws -> Data {
    // If there is already a sheet presented on this window, avoid opening another one
    if let win = anchorWindow, win.attachedSheet != nil {
        log.warning("Access panel is already presented on the anchor window")
        throw NSError(domain: "FavAccess", code: 3, userInfo: [NSLocalizedDescriptionKey: "Panel already presented"])
    }

    let panel = NSOpenPanel()
    panel.title = "Allow access to a volume"
    panel.message = "This is necessary to access mounted system volumes and favorites."
    panel.directoryURL = url
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = false
    panel.canCreateDirectories = false
    panel.showsHiddenFiles = false
    panel.prompt = "Allow"
    panel.treatsFilePackagesAsDirectories = true

    let pickedURL: URL = try await withCheckedThrowingContinuation { cont in
        if let win = anchorWindow {
            panel.beginSheetModal(for: win) { response in
                if response == .OK, let sel = panel.urls.first {
                    cont.resume(returning: sel)
                } else {
                    cont.resume(
                        throwing: NSError(domain: "FavAccess", code: 1, userInfo: [NSLocalizedDescriptionKey: "User cancelled"]))
                }
            }
        } else {
            let resp = panel.runModal()
            if resp == .OK, let sel = panel.urls.first {
                cont.resume(returning: sel)
            } else {
                cont.resume(throwing: NSError(domain: "FavAccess", code: 1, userInfo: [NSLocalizedDescriptionKey: "User cancelled"]))
            }
        }
    }

    let bookmark = try pickedURL.bookmarkData(
        options: [.withSecurityScope],
        includingResourceValuesForKeys: nil,
        relativeTo: nil)
    await BookmarkStore.shared.saveBookmark(for: pickedURL.path, data: bookmark)
    log.info("Saved security-scoped bookmark (sheet) for: \(pickedURL.path)")
    return bookmark
}
