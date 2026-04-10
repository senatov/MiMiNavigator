// DirectoryContextMenu.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 08.10.2025.
// Copyright © 2025-2026 Senatov. All rights reserved.
// Description: Context menu for directories - Finder-style layout

import FavoritesKit
import FileModelKit
import SwiftUI

/// Context menu for directory items.
/// Matches Finder's context menu structure for folders.
struct DirectoryContextMenu: View {
    let file: CustomFile
    let panelSide: FavPanelSide
    let isOptionHeld: Bool
    let onAction: (DirectoryAction) -> Void
    @State private var userFavorites = UserFavoritesStore.shared

    init(file: CustomFile, panelSide: FavPanelSide, isOptionHeld: Bool = false, onAction: @escaping (DirectoryAction) -> Void) {
        self.file = file
        self.panelSide = panelSide
        self.isOptionHeld = isOptionHeld
        self.onAction = onAction
    }

    var body: some View {
        Group {
            .onAppear {
                log.debug("[ContextMenu] appear")
                log.debug("[ContextMenu] dir='\(file.nameStr)'")
                log.debug("[ContextMenu] optionHeld=\(isOptionHeld)")
            }
            .onChange(of: isOptionHeld) { oldValue, newValue in
                log.debug("[ContextMenu] option key changed")
                log.debug("[ContextMenu] old=\(oldValue)")
                log.debug("[ContextMenu] new=\(newValue)")
            }
            // ═══════════════════════════════════════════
            // SECTION 1: Navigation (directory-specific)
            // ═══════════════════════════════════════════
            menuButton(.open)
            menuButton(.openInNewTab)
            menuButton(.openInFinder)
            menuButton(.openInTerminal)
            menuButton(.viewLister)

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
            // SECTION 4: Rename & Delete (⌥ Option only)
            // ═══════════════════════════════════════════
            if isOptionHeld {
                log.debug("[ContextMenu] showing extended actions")
                menuButton(.rename)
                menuButton(.delete)
            }

            Divider()

            // ═══════════════════════════════════════════
            // SECTION 5: Info
            // ═══════════════════════════════════════════
            menuButton(.getInfo)

            Divider()

            // ═══════════════════════════════════════════
            // SECTION 6: Cross-panel
            // ═══════════════════════════════════════════
            menuButton(.openOnOtherPanel)

            Divider()

            // ═══════════════════════════════════════════
            // SECTION 7: Favorites
            // ═══════════════════════════════════════════
            favoritesToggleButton

            // ═══════════════════════════════════════════
            // Option hint
            // ═══════════════════════════════════════════
            if !isOptionHeld {
                log.debug("[ContextMenu] showing option hint")
                Divider()
                Text("⌥ for more…")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.blue)
            }
        }
    }

    // MARK: - Add / Remove Favorites toggle

    @ViewBuilder
    private var favoritesToggleButton: some View {
        let isInFavorites = userFavorites.contains(url: file.urlValue)
        if isInFavorites {
            Button(role: .destructive) {
                userFavorites.remove(url: file.urlValue)
                log.info("[Favorites] directory removed via context menu: \(file.urlValue.path)")
            } label: {
                Label("Remove from Favorites", systemImage: "star.slash.fill")
            }
        } else {
            menuButton(.addToFavorites)
        }
    }

    // MARK: - Menu Button Builder

    @ViewBuilder
    private func menuButton(_ action: DirectoryAction) -> some View {
        Button {
            log.debug("[ContextMenu] tap action")
            log.debug("[ContextMenu] action=\(action.rawValue)")
            log.debug("[ContextMenu] dir='\(file.nameStr)'")
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
                    .symbolRenderingMode(action == .copyAsPathname ? .hierarchical : .monochrome)
                    .foregroundStyle(action == .copyAsPathname ? .blue : .primary)
            }
        }
        .disabled(isActionDisabled(action))
    }

    // MARK: - Action State

    private func isActionDisabled(_ action: DirectoryAction) -> Bool {
        switch action {
            case .paste:
                return !ClipboardManager.shared.hasContent
            default:
                return false
        }
    }
}
