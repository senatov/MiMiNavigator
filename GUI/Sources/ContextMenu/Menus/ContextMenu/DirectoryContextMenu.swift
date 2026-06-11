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
        crossPanelSection
        Divider()
        favoritesSection
        Divider()
        infoSection
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
                    if let shortcut = shortcutHint(for: action) {
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

    private func shortcutHint(for action: DirectoryAction) -> String? {
        if action == .rename {
            return HotKeyStore.shared.shortcutString(for: .renameFile)
        }
        return action.shortcutHint
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
        menuButton(.console)
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
            menuButton(.newFolder)
            menuButton(.newFile)
            menuButton(.rename)
            Divider()
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
        cloudLinkSection
    }

    // MARK: - Cloud Link

    @ViewBuilder
    private var cloudLinkSection: some View {
        Divider()
        Menu {
            let providers = CloudDriveAvailability.shareProviders
            if providers.count > 1 {
                ForEach(providers, id: \.rawValue) { provider in
                    cloudProviderMenu(provider)
                }
            } else if let provider = providers.first {
                cloudProviderActions(provider)
            } else {
                Text("No supported cloud drive connected")
            }
        } label: {
            Label {
                Text("Share+Link")
            } icon: {
                Image(systemName: "link.badge.plus")
            }
        }
    }

    // MARK: - Cloud Provider Menu

    @ViewBuilder
    private func cloudProviderMenu(_ provider: CloudProvider) -> some View {
        Menu {
            cloudProviderActions(provider)
        } label: {
            Label(provider.rawValue, systemImage: provider.systemImage)
        }
    }

    // MARK: - Cloud Provider Actions

    @ViewBuilder
    private func cloudProviderActions(_ provider: CloudProvider) -> some View {
        Button {
            CloudLinkService.generateLink(for: file.urlValue, provider: provider, permission: .readOnly)
        } label: {
            Label("View only", systemImage: "eye")
        }
        if provider == .googleDrive {
            Button {
                CloudLinkService.generateLink(for: file.urlValue, provider: provider, permission: .allowEdit)
            } label: {
                Label("Allow editing", systemImage: "pencil")
            }
        }
    }
}
