// FileContextMenu.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 08.10.2025.
// Copyright © 2025-2026 Senatov. All rights reserved.
// Description: Context menu for files - Finder-style layout with all standard actions

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
        case cloud
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
        .cloud,
        .info,
    ]

    // Keep submenu data frozen for the lifetime of one context menu instance.
    // File rows share one context menu, so the Launch Services lookup only runs
    // when that menu is created and never mutates it while AppKit is tracking.
    let openWithApps: [AppInfo]
    let openWithMenuID: String

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
        let apps = Self.loadOpenWithApps(for: file)
        openWithApps = apps
        openWithMenuID = Self.makeOpenWithMenuID(for: file, apps: apps)
        FileContextMenuLog.logInit(
            instanceID: instanceID,
            fileName: file.nameStr,
            fileExtension: Self.cacheKey(for: file),
            appsCount: apps.count,
            menuID: openWithMenuID
        )
    }

    var body: some View {
        menuContent
            .onAppear {
                logBodyAppearance()
            }
    }

    var resolvedApps: [AppInfo] { openWithApps }

    var resolvedMenuID: String { openWithMenuID }

}
