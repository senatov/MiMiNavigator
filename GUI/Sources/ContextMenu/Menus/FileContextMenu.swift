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

private enum FileContextMenuLog {
    static func logCacheInvalidation(_ ext: String) {
        log.debug("[FileContextMenu] apps cache cleared")
        log.debug("[FileContextMenu] cache ext='\(ext)'")
    }

    static func logCacheObserverMissingExtension() {
        log.warning("[FileContextMenu] cache invalidation without ext")
    }

    static func logFavoriteRemoved(path: String) {
        log.info("[Favorites] directory removed via context menu")
        log.info("[Favorites] path='\(path)'")
    }

    static func logInit(instanceID: Int, fileName: String, fileExtension: String, appsCount: Int, menuID: String) {
        log.debug("[FileContextMenu] init#\(instanceID) file='\(fileName)'")
        log.debug("[FileContextMenu] init#\(instanceID) ext='\(fileExtension)' apps=\(appsCount)")
        log.debug("[FileContextMenu] init#\(instanceID) menuID='\(menuID)'")
    }

    static func logBody(prefix: String, snapshot: FileContextMenu.DebugSnapshot) {
        log.debug("\(prefix) body \(snapshot.fileLine)")
        log.debug("\(prefix) \(snapshot.menuLine)")
    }

    static func logAction(prefix: String, action: String, snapshot: FileContextMenu.DebugSnapshot) {
        log.debug("\(prefix) action='\(action)' \(snapshot.fileLine)")
        log.debug("\(prefix) path='\(snapshot.path)'")
        log.debug("\(prefix) \(snapshot.menuLine)")
    }

    static func logFavoriteAdd(prefix: String, snapshot: FileContextMenu.DebugSnapshot) {
        log.debug("\(prefix) add favorite dir='\(snapshot.fileName)'")
        log.debug("\(prefix) add favorite path='\(snapshot.path)'")
    }

    static func logFavoriteRemove(prefix: String, snapshot: FileContextMenu.DebugSnapshot) {
        log.debug("\(prefix) remove favorite dir='\(snapshot.fileName)'")
        log.debug("\(prefix) remove favorite path='\(snapshot.path)'")
    }

    static func logMediaInfo(fileName: String, path: String) {
        log.debug("[FileContextMenu] media info file='\(fileName)'")
        log.debug("[FileContextMenu] media info path='\(path)'")
    }

    static func logOpenWithCacheHit(_ ext: String) {
        log.debug("[FileContextMenu] open-with cache hit ext='\(ext)'")
    }

    static func logOpenWithCacheMiss(_ ext: String) {
        log.debug("[FileContextMenu] open-with cache miss ext='\(ext)'")
    }
}

private enum FileContextMenuConfig {
    static let videoExtensions: Set<String> = [
        "mp4", "mov", "mkv", "avi", "wmv", "flv", "webm", "m4v", "3gp",
    ]

    static let audioExtensions: Set<String> = [
        "mp3", "wav", "flac", "aac", "ogg", "m4a", "wma", "aiff",
    ]

    static let imageExtensions: Set<String> = [
        "jpg", "jpeg", "png", "gif", "heic", "heif", "bmp", "tiff", "webp", "ico",
    ]

    static let mediaConformingTypes: [UTType] = [.image, .movie, .audio]

    static func isKnownMediaExtension(_ ext: String) -> Bool {
        videoExtensions.contains(ext)
            || audioExtensions.contains(ext)
            || imageExtensions.contains(ext)
    }
}

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

    nonisolated private static func cacheKey(for file: CustomFile) -> String {
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
    private let onAction: (FileAction) -> Void

    private let sectionOrder: [SectionKind] = [
        .media,
        .open,
        .edit,
        .operations,
        .navigation,
        .danger,
        .info,
        .favorites,
    ]

    private let userFavorites = UserFavoritesStore.shared

    @State private var openWithApps: [AppInfo]
    @State private var openWithMenuID: String

    fileprivate struct DebugSnapshot {
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

    private var filePath: String { file.urlValue.path }

    private var fileExtension: String { file.urlValue.pathExtension.lowercased() }

    private var debugPrefix: String { "[FileContextMenu] #\(instanceID)" }

    private var debugSnapshot: DebugSnapshot {
        DebugSnapshot(
            fileName: file.nameStr,
            fileExtension: fileExtension,
            appsCount: openWithApps.count,
            menuID: openWithMenuID,
            path: filePath
        )
    }

    private var isFavoriteDirectory: Bool {
        file.isDirectory && userFavorites.contains(url: file.urlValue)
    }

    private var isMediaFile: Bool {
        Self.isMediaFile(file)
    }

    init(file: CustomFile, panelSide _: FavPanelSide, onAction: @escaping (FileAction) -> Void) {
        _ = Self.cacheObserver

        let instanceID = Self.makeNextDebugID()
        let initialApps = Self.loadOpenWithApps(for: file)
        let initialMenuID = Self.makeOpenWithMenuID(for: file, apps: initialApps)

        self.instanceID = instanceID
        self.file = file
        self.onAction = onAction
        _openWithApps = State(initialValue: initialApps)
        _openWithMenuID = State(initialValue: initialMenuID)

        FileContextMenuLog.logInit(
            instanceID: instanceID,
            fileName: file.nameStr,
            fileExtension: Self.cacheKey(for: file),
            appsCount: initialApps.count,
            menuID: initialMenuID
        )
    }

    var body: some View {
        menuBody
            .onAppear(perform: logBodyAppearance)
    }

    // MARK: - Snapshot Helpers

    @ViewBuilder
    private var menuBody: some View {
        Group {
            menuContent
        }
    }

    @ViewBuilder
    private var menuContent: some View {
        ForEach(sectionOrder, id: \.self) { section in
            sectionView(for: section)
        }
    }

    private func makeSnapshot() -> DebugSnapshot {
        debugSnapshot
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
            case .open, .edit, .operations, .navigation, .danger, .info:
                return true
            case .favorites:
                return file.isDirectory
        }
    }

    // MARK: - Media

    @ViewBuilder
    private var mediaSection: some View {
        if isMediaFile {
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

        OpenWithSubmenu(file: file, apps: openWithApps)
            .id(openWithMenuID)

        menuButton(.openInNewTab)
        menuButton(.viewLister)
        archiveSourceIndicator

        sectionDivider(after: .open)
    }

    @ViewBuilder
    private var editSection: some View {
        menuButton(.cut)
        menuButton(.copy)
        menuButton(.copyAsPathname)
        menuButton(.paste)
        menuButton(.duplicate)

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
        menuButton(.rename)
        menuButton(.delete)

        sectionDivider(after: .danger)
    }

    @ViewBuilder
    private var infoSection: some View {
        menuButton(.getInfo)

        sectionDivider(after: .info)
    }

    @ViewBuilder
    private var favoritesSection: some View {
        if file.isDirectory {
            favoritesToggleButton
        }
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

    nonisolated private static func makeOpenWithMenuID(for file: CustomFile, apps: [AppInfo]) -> String {
        let submenuSignature = apps.map(\.bundleIdentifier).joined(separator: ",")
        return "openwith|\(file.urlValue.path)|\(submenuSignature)"
    }

    // MARK: - Action Handling

    private func logBodyAppearance() {
        let snapshot = makeSnapshot()
        FileContextMenuLog.logBody(prefix: debugPrefix, snapshot: snapshot)
    }

    private func handleAction(_ action: FileAction) {
        let snapshot = makeSnapshot()
        logAction(action, snapshot: snapshot)
        onAction(action)
    }

    private func performAction(_ action: FileAction) {
        handleAction(action)
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
        file.isDirectory && !isFavoriteDirectory
    }

    // MARK: - Action State

    private var isAddToFavoritesDisabled: Bool {
        !canAddToFavorites()
    }

    private func isActionDisabled(_ action: FileAction) -> Bool {
        switch action {
            case .paste:
                !ClipboardManager.shared.hasContent
            case .addToFavorites:
                isAddToFavoritesDisabled
            default:
                false
        }
    }
}
