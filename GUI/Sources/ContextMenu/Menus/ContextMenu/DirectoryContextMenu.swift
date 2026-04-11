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

    var body: some View {
        moreFolderOperationsMenu
        Divider()
        navigationSection
        Divider()
        editSection
        Divider()
        operationsSection
        Divider()
        infoSection
        Divider()
        crossPanelSection
        Divider()
        favoritesSection
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
    func menuButton(_ action: DirectoryAction) -> some View {
        Button {
            log.debug("[DirectoryContextMenu] tap action=\(action.rawValue) dir='\(file.nameStr)' optionHeld=\(isOptionHeld)")
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
                let disabled = !ClipboardManager.shared.hasContent
                log.debug("[DirectoryContextMenu] paste availability dir='\(file.nameStr)' hasContent=\(!disabled)")
                return disabled
            default:
                return false
        }
    }

    // MARK: - Sections
    @ViewBuilder
    private var navigationSection: some View {
        menuButton(.open)
        menuButton(.openInNewTab)
        menuButton(.openInFinder)
        menuButton(.openInTerminal)
        menuButton(.viewLister)
    }

    @ViewBuilder
    private var editSection: some View {
        menuButton(.copyAsPathname)
    }

    @ViewBuilder
    private var operationsSection: some View {
        menuButton(.compress)
        menuButton(.share)
    }




    @ViewBuilder
    private var moreFolderOperationsMenu: some View {
        Menu {
            menuButton(.cut)
            menuButton(.copy)
            menuButton(.paste)
            menuButton(.duplicate)
            Divider()
            menuButton(.createLink)
            Divider()
            Menu {
                Button("Make Finder Alias") {
                }
                .disabled(true)
                Button("Make Symbolic Link") {
                }
                .disabled(true)
            } label: {
                Label("Make Alias", systemImage: "link")
            }
            Divider()
            menuButton(.rename)
            menuButton(.delete)
        } label: {
            Label {
                Text("􀉒 Folder Operations")
            } icon: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    @ViewBuilder
    private var infoSection: some View {
        menuButton(.getInfo)
    }

    @ViewBuilder
    private var crossPanelSection: some View {
        menuButton(.openOnOtherPanel)
        menuButton(.mirrorPanel)
    }

    @ViewBuilder
    private var favoritesSection: some View {
        favoritesToggleButton
    }
}
