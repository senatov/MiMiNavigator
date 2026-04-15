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
    private enum OpenWithCache {
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

    private enum SectionKind: CaseIterable {
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
    private static var nextDebugID: Int = 0

    @MainActor
    private static var appsCache: [String: [AppInfo]] = [:]

    private static func cacheKey(for file: CustomFile) -> String {
        file.urlValue.pathExtension.lowercased()
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

    private let instanceID: Int
    private let file: CustomFile
    private let isOptionHeld: Bool
    private let onAction: (FileAction) -> Void

    private let sectionOrder: [SectionKind] = [
        .danger,
        .media,
        .open,
        .edit,
        .operations,
        .navigation,
        .favorites,
    ]

    private let userFavorites = UserFavoritesStore.shared

    // Keep submenu data frozen for the lifetime of one context menu instance.
    // Rebuilding the submenu identity while AppKit is tracking the menu can
    // cause item/view mismatches and visible flicker.
    // Lazy-loaded on first body eval (not in init!) to avoid O(N) LS lookups
    // when SwiftUI diffs 1500+ rows in large directories.
    @State private var openWithApps: [AppInfo]?
    @State private var openWithMenuID: String?
    @State private var lastOptionState: Bool = false

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

    private var filePath: String { file.urlValue.path }

    private var fileExtension: String { file.urlValue.pathExtension.lowercased() }

    private var debugPrefix: String { "[FileContextMenu] #\(instanceID)" }

    private var debugSnapshot: DebugSnapshot {
        DebugSnapshot(
            fileName: file.nameStr,
            fileExtension: fileExtension,
            appsCount: resolvedApps.count,
            menuID: resolvedMenuID,
            path: filePath
        )
    }

    private var isFavoriteDirectory: Bool {
        file.isDirectory && userFavorites.contains(url: file.urlValue)
    }

    private var isMediaFile: Bool {
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
                lastOptionState = isOptionHeld
                ensureOpenWithLoaded()
                logBodyAppearance()
            }
            .onChange(of: isOptionHeld) { oldValue, newValue in
                log.debug("[FileContextMenu] option key changed file='\(file.nameStr)' old=\(oldValue) new=\(newValue)")
                lastOptionState = newValue
            }
    }

    // MARK: - Lazy OpenWith Loading

    /// Loads open-with apps on first body eval (context menu actually shown).
    /// This avoids O(N) LS lookups when SwiftUI diffs 1500+ rows.
    private func ensureOpenWithLoaded() {
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
    private var resolvedApps: [AppInfo] { openWithApps ?? [] }

    /// Resolved menu ID — fallback until loaded
    private var resolvedMenuID: String { openWithMenuID ?? "openwith|\(file.urlValue.path)|pending" }

    // MARK: - Snapshot Helpers


    @ViewBuilder
    private var menuContent: some View {
        ForEach(sectionOrder, id: \.self) { section in
            sectionView(for: section)
        }
    }

    private func makeSnapshot() -> DebugSnapshot {
        logSnapshot
    }

    @ViewBuilder
    private func sectionView(for section: SectionKind) -> some View {
        switch section {
            case .media:
                mediaSection
            case .open:
                openSection
            case .edit:
                editSection
            case .operations:
                operationsSection
            case .navigation:
                navigationSection
            case .danger:
                dangerSection
            case .info:
                infoSection
            case .favorites:
                favoritesSection
        }
    }

    private func shouldShowDivider(after section: SectionKind) -> Bool {
        section != .favorites && hasVisibleContent(after: section)
    }

    private func hasVisibleContent(after section: SectionKind) -> Bool {
        guard let index = sectionOrder.firstIndex(of: section) else {
            return false
        }

        let remainingSections = sectionOrder.dropFirst(index + 1)
        return remainingSections.contains(where: hasVisibleContent(in:))
    }

    private func hasVisibleContent(in section: SectionKind) -> Bool {
        switch section {
            case .media:
                return isMediaFile
            case .danger:
                return true
            case .open, .edit, .operations, .navigation, .info:
                return true
            case .favorites:
                return true
        }
    }

    // MARK: - Media

    @ViewBuilder
    private var mediaSection: some View {
        if isMediaFile {
            menuButton(.convertMedia)
            Button {
                FileContextMenuLog.logMediaInfo(fileName: file.nameStr, path: filePath)
                MediaInfoGetter().getMediaInfoToFile(url: file.urlValue)
            } label: {
                Label("Get Media Info", systemImage: "info.circle")
            }
            sectionDivider(after: .media)
        }
    }

    @ViewBuilder
    private var openSection: some View {
        menuButton(.open)

        if file.isAppBundle {
            menuButton(.browseContents)
        }

        OpenWithSubmenu(file: file, apps: resolvedApps)

        menuButton(.openInNewTab)
        menuButton(.viewLister)
        archiveSourceIndicator

        sectionDivider(after: .open)
    }

    @ViewBuilder
    private var editSection: some View {
        menuButton(.copyAsPathname)

        sectionDivider(after: .edit)
    }

    @ViewBuilder
    private var operationsSection: some View {
        menuButton(.compress)
        menuButton(.share)

        sectionDivider(after: .operations)
    }

    @ViewBuilder
    private var navigationSection: some View {
        menuButton(.revealInFinder)

        sectionDivider(after: .navigation)
    }

    @ViewBuilder
    private var dangerSection: some View {
        moreFileOperationsMenu
        sectionDivider(after: .danger)
    }



    @ViewBuilder
    private var moreFileOperationsMenu: some View {
        Menu {
            menuButton(.newFolder)
            menuButton(.newFile)
            Divider()
            menuButton(.cut)
            menuButton(.copy)
            menuButton(.paste)
            menuButton(.duplicate)
            Divider()
            menuButton(.createLink)
            menuButton(.rename)
            menuButton(.delete)
            Divider()
            menuButton(.getInfo)
        } label: {
            Label {
                Text("􀉒 File Operations")
            } icon: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    @ViewBuilder
    private var infoSection: some View {
        EmptyView()
    }

    @ViewBuilder
    private var favoritesSection: some View {
        menuButton(.mirrorPanel)
        menuButton(.addToFavorites)
    }


    @ViewBuilder
    private func sectionDivider(after section: SectionKind) -> some View {
        if shouldShowDivider(after: section) {
            Divider()
        }
    }

    @ViewBuilder
    private var archiveSourceIndicator: some View {
        if file.isFromArchiveSearch, let archivePath = file.archiveSourcePath {
            Label {
                Text("In: \((archivePath as NSString).lastPathComponent)")
                    .foregroundStyle(.secondary)
            } icon: {
                Image(systemName: "archivebox")
                    .foregroundStyle(.orange)
            }
            .font(.caption)
        }
    }

    nonisolated private static func isMediaFile(_ file: CustomFile) -> Bool {
        let fileExtension = file.urlValue.pathExtension.lowercased()
        let resolvedType = UTType(filenameExtension: fileExtension)
        let conformsToMediaType =
            resolvedType.map { type in
                FileContextMenuConfig.mediaConformingTypes.contains { type.conforms(to: $0) }
            } ?? false

        if conformsToMediaType {
            return true
        }
        return FileContextMenuConfig.isKnownMediaExtension(fileExtension)
    }

    // MARK: - Favorites

    @ViewBuilder
    private var favoritesToggleButton: some View {
        if isFavoriteDirectory {
            Button(role: .destructive) {
                removeDirectoryFromFavorites()
            } label: {
                Label("Remove from Favorites", systemImage: "star.slash.fill")
            }
        } else {
            Button {
                addDirectoryToFavorites()
            } label: {
                menuLabel(for: .addToFavorites)
            }
            .disabled(isActionDisabled(.addToFavorites))
        }
    }

    // MARK: - Menu Button Builder

    @ViewBuilder
    private func menuButton(_ action: FileAction) -> some View {
        Button {
            performAction(action)
        } label: {
            menuLabel(for: action)
        }
        .disabled(isActionDisabled(action))
    }

    // MARK: - Static Helpers

    @MainActor
    private static func makeNextDebugID() -> Int {
        nextDebugID += 1
        return nextDebugID
    }

    @MainActor
    private static func loadOpenWithApps(for file: CustomFile) -> [AppInfo] {
        let cacheKey = cacheKey(for: file)

        if let cachedApps = OpenWithCache.cachedApps(for: file) {
            FileContextMenuLog.logOpenWithCacheHit(cacheKey)
            return cachedApps
        }

        FileContextMenuLog.logOpenWithCacheMiss(cacheKey)

        let loadedApps = OpenWithService.shared.getApplications(for: file.urlValue)
        OpenWithCache.store(loadedApps, for: file)

        return loadedApps
    }

    private static func makeOpenWithMenuID(for file: CustomFile, apps: [AppInfo]) -> String {
        let submenuSignature =
            apps
            .map(\.bundleIdentifier)
            .sorted()
            .joined(separator: ",")
        return "openwith|\(file.urlValue.path)|\(submenuSignature)"
    }

    // MARK: - Action Handling

    private func logBodyAppearance() {
        let snapshot = makeSnapshot()
        FileContextMenuLog.logBody(prefix: debugPrefix, snapshot: snapshot)
    }

    private func performAction(_ action: FileAction) {
        let snapshot = makeSnapshot()
        logAction(action, snapshot: snapshot)
        onAction(action)
    }

    private func logAction(_ action: FileAction, snapshot: DebugSnapshot) {
        FileContextMenuLog.logAction(
            prefix: debugPrefix,
            action: action.rawValue,
            snapshot: snapshot
        )
    }

    private func addDirectoryToFavorites() {
        let snapshot = makeSnapshot()
        FileContextMenuLog.logFavoriteAdd(prefix: debugPrefix, snapshot: snapshot)
        performAction(.addToFavorites)
    }

    private func logFavoriteRemovalSkipped(path: String) {
        log.warning("[Favorites] remove skipped")
        log.warning("[Favorites] reason='directory is not in favorites'")
        log.warning("[Favorites] path='\(path)'")
    }

    private func removeDirectoryFromFavorites() {
        let snapshot = makeSnapshot()
        FileContextMenuLog.logFavoriteRemove(prefix: debugPrefix, snapshot: snapshot)

        guard isFavoriteDirectory else {
            logFavoriteRemovalSkipped(path: snapshot.path)
            return
        }

        userFavorites.remove(url: file.urlValue)
        FileContextMenuLog.logFavoriteRemoved(path: snapshot.path)
    }

    // MARK: - Label Builder

    @ViewBuilder
    private func menuLabel(for action: FileAction) -> some View {
        Label {
            HStack {
                Text(action.title)
                Spacer()
                shortcutView(for: action)
            }
        } icon: {
            menuIcon(for: action)
        }
    }

    @ViewBuilder
    private func shortcutView(for action: FileAction) -> some View {
        if let shortcut = action.shortcutHint {
            Text(shortcut)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func menuIcon(for action: FileAction) -> some View {
        Image(systemName: action.systemImage)
            .symbolRenderingMode(iconRenderingMode(for: action))
            .foregroundStyle(iconColor(for: action))
    }

    // MARK: - Icon Styling

    private func iconRenderingMode(for action: FileAction) -> SymbolRenderingMode {
        switch action {
            case .copyAsPathname:
                .hierarchical
            default:
                .monochrome
        }
    }

    private func iconColor(for action: FileAction) -> Color {
        switch action {
            case .copyAsPathname:
                .blue
            default:
                .primary
        }
    }

    private func canAddToFavorites() -> Bool {
        // For files: always enabled (adds parent dir to favorites)
        // For directories: enabled unless already in favorites
        if file.isDirectory {
            return !isFavoriteDirectory
        }
        return true
    }

    // MARK: - Action State

    private var isAddToFavoritesDisabled: Bool {
        !canAddToFavorites()
    }

    private func isActionDisabled(_ action: FileAction) -> Bool {
        switch action {
            case .paste:
                let disabled = !ClipboardManager.shared.hasContent
                log.debug("[FileContextMenu] paste availability file='\(file.nameStr)' hasContent=\(!disabled)")
                return disabled
            case .addToFavorites:
                return isAddToFavoritesDisabled
            default:
                return false
        }
    }
}
