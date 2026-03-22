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
struct FileContextMenu: View {
    /// Cache of Open With apps by file extension
    private static var appsCache: [String: [AppInfo]] = [:]
    // MARK: - Cache Observer
    /// One-time observer setup for LRU cache invalidation from OpenWithService
    private static let cacheObserver: Any = {
        NotificationCenter.default.addObserver(
            forName: OpenWithService.cacheInvalidatedNotification,
            object: nil, queue: .main
        ) { notification in
            let ext = notification.userInfo?["ext"] as? String
            MainActor.assumeIsolated {
                guard let ext else { return }
                appsCache.removeValue(forKey: ext)
                log.debug("FileContextMenu.appsCache cleared for ext='\(ext)'")
            }
        }
    }()
    let file: CustomFile
    let panelSide: PanelSide
    let onAction: (FileAction) -> Void
    @Environment(\.dismiss) private var dismiss
    private let userFavorites = UserFavoritesStore.shared
    // Pre-loaded once at init — prevents re-init of OpenWithSubmenu on every body re-evaluation
    @State private var openWithApps: [AppInfo]

    init(file: CustomFile, panelSide: PanelSide, onAction: @escaping (FileAction) -> Void) {
        _ = Self.cacheObserver  // ensure observer is registered
        self.file = file
        self.panelSide = panelSide
        self.onAction = onAction
        let ext = file.urlValue.pathExtension.lowercased()

        // Static cache per file extension to avoid thousands of LaunchServices queries
        if let cached = FileContextMenu.appsCache[ext] {
            _openWithApps = State(initialValue: cached)
        } else {
            let apps = OpenWithService.shared.getApplications(for: file.urlValue)
            FileContextMenu.appsCache[ext] = apps
            _openWithApps = State(initialValue: apps)
        }
    }

    var body: some View {
        Group {
            // ═══════════════════════════════════════════
            // SECTION 0: Media
            // ═══════════════════════════════════════════
            if isMediaFile(file) {
                Button {
                    log.debug("[FileContextMenu] get media info file='\(file.nameStr)' path='\(file.urlValue.path)'")
                    MediaInfoGetter().getMediaInfoToFile(url: file.urlValue)
                } label: {
                    Label("Get Media Info", systemImage: "info.circle")
                }

                Divider()
            }
            // ═══════════════════════════════════════════
            // SECTION 1: Open actions
            // ═══════════════════════════════════════════
            menuButton(.open)
            if file.isAppBundle {
                menuButton(.browseContents)
            }
            OpenWithSubmenu(file: file, apps: openWithApps)
            menuButton(.openInNewTab)
            menuButton(.viewLister)

            // Archive source indicator (when file comes from archive search)
            if file.isFromArchiveSearch, let archPath = file.archiveSourcePath {
                Label {
                    Text("In: \((archPath as NSString).lastPathComponent)")
                        .foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: "archivebox")
                        .foregroundStyle(.orange)
                }
                .font(.caption)
            }

            Divider()

            // ═══════════════════════════════════════════
            // SECTION 2: Edit actions (clipboard)
            // ═══════════════════════════════════════════
            menuButton(.cut)
            menuButton(.copy)
            menuButton(.copyAsPathname)
            menuButton(.paste)
            menuButton(.duplicate)

            Divider()

            // ═══════════════════════════════════════════
            // SECTION 3: Operations
            // ═══════════════════════════════════════════
            menuButton(.compress)
            menuButton(.share)

            Divider()

            // ═══════════════════════════════════════════
            // SECTION 4: Navigation
            // ═══════════════════════════════════════════
            menuButton(.revealInFinder)

            Divider()

            // ═══════════════════════════════════════════
            // SECTION 5: Rename & Delete (danger zone)
            // ═══════════════════════════════════════════
            menuButton(.rename)
            menuButton(.delete)

            Divider()

            // ═══════════════════════════════════════════
            // SECTION 6: Info
            // ═══════════════════════════════════════════
            menuButton(.getInfo)

            Divider()

            // ═══════════════════════════════════════════
            // SECTION 7: Favorites
            // ═══════════════════════════════════════════
            favoritesToggleButton
        }
    }

    // MARK: - Media

    private func isMediaFile(_ file: CustomFile) -> Bool {
        let ext = file.urlValue.pathExtension.lowercased()

        // Primary detection via UTType (Finder-level behavior)
        if let type = UTType(filenameExtension: ext) {
            if type.conforms(to: .image)
                || type.conforms(to: .movie)
                || type.conforms(to: .audio) {
                return true
            }
        }

        // Fallback for unknown / uncommon extensions
        let video: Set<String> = [
            "mp4","mov","mkv","avi","wmv","flv","webm","m4v","3gp"
        ]

        let audio: Set<String> = [
            "mp3","wav","flac","aac","ogg","m4a","wma","aiff"
        ]

        let image: Set<String> = [
            "jpg","jpeg","png","gif","heic","heif","bmp","tiff","webp","ico"
        ]

        return video.contains(ext) || audio.contains(ext) || image.contains(ext)
    }

    // MARK: - Add / Remove Favorites toggle

    @ViewBuilder
    private var favoritesToggleButton: some View {
        // Show only for directories
        if file.isDirectory {
            let isInFavorites = userFavorites.contains(url: file.urlValue)
            if isInFavorites {
                Button(role: .destructive) {
                    log.debug("[FileContextMenu] remove favorite dir='\(file.nameStr)' path='\(file.urlValue.path)'")
                    userFavorites.remove(url: file.urlValue)
                    log.info("[Favorites] directory removed via context menu: \(file.urlValue.path)")
                } label: {
                    Label("Remove from Favorites", systemImage: "star.slash.fill")
                }
            } else {
                Button {
                    log.debug("[FileContextMenu] add favorite dir='\(file.nameStr)' path='\(file.urlValue.path)'")
                    handleAction(.addToFavorites)
                } label: {
                    menuLabel(for: .addToFavorites)
                }
                .disabled(isActionDisabled(.addToFavorites))
            }
        }
    }

    // MARK: - Menu Button Builder

    @ViewBuilder
    private func menuButton(_ action: FileAction) -> some View {
        Button {
            handleAction(action)
        } label: {
            menuLabel(for: action)
        }
        .disabled(isActionDisabled(action))
    }

    // MARK: - Action Handling

    private func handleAction(_ action: FileAction) {
        log.debug("[FileContextMenu] action='\(action.rawValue)' file='\(file.nameStr)' path='\(file.urlValue.path)'")
        onAction(action)
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

    private func menuIcon(for action: FileAction) -> some View {
        Image(systemName: action.systemImage)
            .symbolRenderingMode(iconRenderingMode(for: action))
            .foregroundStyle(iconColor(for: action))
    }

    // MARK: - Icon Styling

    private func iconRenderingMode(for action: FileAction) -> SymbolRenderingMode {
        action == .copyAsPathname ? .hierarchical : .monochrome
    }

    private func iconColor(for action: FileAction) -> Color {
        action == .copyAsPathname ? .blue : .primary
    }

    // MARK: - Action State

    private func isActionDisabled(_ action: FileAction) -> Bool {
        switch action {
            case .paste:
                return !ClipboardManager.shared.hasContent
            default:
                return false
        }
    }
}
