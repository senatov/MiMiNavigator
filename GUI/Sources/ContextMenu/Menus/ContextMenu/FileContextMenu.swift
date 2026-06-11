// FileContextMenu.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 08.10.2025.
// Copyright © 2025-2026 Senatov. All rights reserved.
// Description: Context menu for files - Finder-style layout with all standard actions

import FavoritesKit
import FileModelKit
import SwiftUI
import UniformTypeIdentifiers

/// Context menu for file items (non-directory).
/// Matches Finder's context menu structure and functionality.
@MainActor
struct FileContextMenu: View {

    @MainActor
    enum OpenWithCache {
        static func cachedApps(for file: CustomFile) -> [AppInfo]? {
            let key = FileContextMenu.cacheKey(for: file)
            return FileContextMenu.appsCache[key]
        }

        static func store(_ apps: [AppInfo], for file: CustomFile) {
            let key = FileContextMenu.cacheKey(for: file)
            FileContextMenu.appsCache[key] = apps
        }

        static func removeAll(forFileExtension ext: String) {
            FileContextMenu.appsCache.removeValue(forKey: ext)
        }
    }

    enum SectionKind: CaseIterable {
        case media
        case open
        case edit
        case operations
        case navigation
        case danger
        case info
        case favorites
    }

    @MainActor
    static var nextDebugID: Int = 0

    @MainActor
    static var appsCache: [String: [AppInfo]] = [:]

    static func cacheKey(for file: CustomFile) -> String {
        OpenWithService.shared.normalizedCacheExtension(for: file.urlValue.pathExtension)
    }

    // MARK: - Cache Observer

    private static let cacheObserver: Any = {
        NotificationCenter.default.addObserver(
            forName: OpenWithService.cacheInvalidatedNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard let ext = notification.userInfo?["ext"] as? String else {
                FileContextMenuLog.logCacheObserverMissingExtension()
                return
            }

            MainActor.assumeIsolated {
                OpenWithCache.removeAll(forFileExtension: ext)
                FileContextMenuLog.logCacheInvalidation(ext)
            }
        }
    }()

    let instanceID: Int
    let file: CustomFile
    let isOptionHeld: Bool
    let onAction: (FileAction) -> Void

    let sectionOrder: [SectionKind] = [
        .danger,
        .media,
        .open,
        .edit,
        .operations,
        .navigation,
        .favorites,
        .info,
    ]

    var userFavorites: UserFavoritesStore { .shared }

    // Keep submenu data frozen for the lifetime of one context menu instance.
    // Rebuilding the submenu identity while AppKit is tracking the menu can
    // cause item/view mismatches and visible flicker.
    // Lazy-loaded on first body eval (not in init!) to avoid O(N) LS lookups
    // when SwiftUI diffs 1500+ rows in large directories.
    @State var openWithApps: [AppInfo]?
    @State var openWithMenuID: String?

    struct DebugSnapshot {
        let fileName: String
        let fileExtension: String
        let appsCount: Int
        let menuID: String
        let path: String

        var fileLine: String {
            "file='\(fileName)' ext='\(fileExtension)' apps=\(appsCount)"
        }

        var menuLine: String {
            "menuID='\(menuID)'"
        }
    }

    var logSnapshot: DebugSnapshot {
        debugSnapshot
    }

    var filePath: String { file.urlValue.path }

    var fileExtension: String { file.urlValue.pathExtension.lowercased() }

    var debugPrefix: String { "[FileContextMenu] #\(instanceID)" }

    var debugSnapshot: DebugSnapshot {
        DebugSnapshot(
            fileName: file.nameStr,
            fileExtension: fileExtension,
            appsCount: resolvedApps.count,
            menuID: resolvedMenuID,
            path: filePath
        )
    }

    var isFavoriteDirectory: Bool {
        file.isDirectory && userFavorites.contains(url: file.urlValue)
    }

    var isMediaFile: Bool {
        Self.isMediaFile(file)
    }

    init(file: CustomFile, panelSide _: FavPanelSide, isOptionHeld: Bool = false, onAction: @escaping (FileAction) -> Void) {
        _ = Self.cacheObserver
        let instanceID = Self.makeNextDebugID()
        self.instanceID = instanceID
        self.file = file
        self.isOptionHeld = isOptionHeld
        self.onAction = onAction
        // openWithApps/openWithMenuID stay nil — loaded lazily in body
    }

    var body: some View {
        menuContent
            .onAppear {
                ensureOpenWithLoaded()
                logBodyAppearance()
            }
    }

    // MARK: - Lazy OpenWith Loading

    /// Loads open-with apps on first body eval (context menu actually shown).
    /// This avoids O(N) LS lookups when SwiftUI diffs 1500+ rows.
    func ensureOpenWithLoaded() {
        guard openWithApps == nil else { return }
        let apps = Self.loadOpenWithApps(for: file)
        let menuID = Self.makeOpenWithMenuID(for: file, apps: apps)
        openWithApps = apps
        openWithMenuID = menuID
        FileContextMenuLog.logInit(
            instanceID: instanceID,
            fileName: file.nameStr,
            fileExtension: Self.cacheKey(for: file),
            appsCount: apps.count,
            menuID: menuID
        )
    }

    /// Resolved apps — empty until context menu is actually shown
    var resolvedApps: [AppInfo] { openWithApps ?? [] }

    /// Resolved menu ID — fallback until loaded
    var resolvedMenuID: String { openWithMenuID ?? "openwith|\(file.urlValue.path)|pending" }

}
