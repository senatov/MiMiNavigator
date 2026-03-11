    // FileContextMenu.swift
    // MiMiNavigator
    //
    // Created by Iakov Senatov on 08.10.2025.
    // Copyright © 2025-2026 Senatov. All rights reserved.
    // Description: Context menu for files - Finder-style layout with all standard actions

    import FavoritesKit
    import SwiftUI
    import FileModelKit

    /// Context menu for file items (non-directory).
    /// Matches Finder's context menu structure and functionality.
    struct FileContextMenu: View {
        /// Cache of Open With apps by file extension
        private static var appsCache: [String: [AppInfo]] = [:]
        let file: CustomFile
        let panelSide: PanelSide
        let onAction: (FileAction) -> Void
        @Environment(\.dismiss) private var dismiss
        private let userFavorites = UserFavoritesStore.shared
        // Pre-loaded once at init — prevents re-init of OpenWithSubmenu on every body re-evaluation
        @State private var openWithApps: [AppInfo]

        init(file: CustomFile, panelSide: PanelSide, onAction: @escaping (FileAction) -> Void) {
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

        // MARK: - Add / Remove Favorites toggle

        @ViewBuilder
        private var favoritesToggleButton: some View {
            let isInFavorites = userFavorites.contains(url: file.urlValue)
            if isInFavorites {
                Button(role: .destructive) {
                    userFavorites.remove(url: file.urlValue)
                    log.info("[Favorites] file removed via context menu: \(file.urlValue.path)")
                } label: {
                    Label("Remove from Favorites", systemImage: "star.slash.fill")
                }
            } else {
                menuButton(.addToFavorites)
            }
        }

        // MARK: - Menu Button Builder

        @ViewBuilder
        private func menuButton(_ action: FileAction) -> some View {
            Button {
                log.debug("\(#function) action=\(action.rawValue) file='\(file.nameStr)'")
                onAction(action)
            } label: {
                Label {
                    HStack {
                        Text(action.title)
                        Spacer()
                        if let shortcut = action.shortcutHint {
                            Text(shortcut)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } icon: {
                    Image(systemName: action.systemImage)
                }
            }
            .disabled(isActionDisabled(action))
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

    // MARK: - Preview
    #Preview {
        VStack {
            Text("Right-click for file menu")
        }
        .frame(width: 300, height: 200)
        .contextMenu {
            FileContextMenu(
                file: CustomFile(
                    url: URL(fileURLWithPath: "/test/document.txt"),
                    resourceValues: URLResourceValues()
                ),
                panelSide: .left,
                onAction: { action in
                    log.debug("Action: \(action)")
                }
            )
        }
    }
