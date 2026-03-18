//
//  TopMenuCommands.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 13.03.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//  Description: Commands, Net, and Show menu categories.
//               Extracted from TopMenuMetadata.swift.

import AppKit
import Foundation

// MARK: - Commands Menu
    @MainActor
    let commandMenuCategory = MenuCategory(
        title: "Commands",
        icon: "terminal",
        items: [
            MenuItem(
                title: "Find Files…",
                icon: "magnifyingglass",
                action: {
                    guard let appState = AppStateProvider.shared else { return }
                    let panel = appState.focusedPanel
                    let path = appState.path(for: panel)
                    let file = panel == .left ? appState.selectedLeftFile : appState.selectedRightFile
                    FindFilesCoordinator.shared.toggle(searchPath: path, selectedFile: file, appState: appState)
                },
                hotKey: .findFiles
            ),
            MenuItem(
                title: "Open in Terminal",
                icon: "apple.terminal",
                action: {
                    guard let appState = AppStateProvider.shared else { return }
                    let panel = appState.focusedPanel
                    let path = appState.path(for: panel)
                    let url = URL(fileURLWithPath: path)
                    ContextMenuCoordinator.shared.openTerminal(at: url)
                },
                shortcut: nil
            ),
            MenuItem(
                title: "Open in Finder",
                icon: "folder",
                action: {
                    guard let appState = AppStateProvider.shared else { return }
                    let panel = appState.focusedPanel
                    let path = appState.path(for: panel)
                    let file = panel == .left ? appState.selectedLeftFile : appState.selectedRightFile
                    if let f = file {
                        ContextMenuCoordinator.shared.openInFinder(f)
                    } else {
                        NSWorkspace.shared.open(URL(fileURLWithPath: path))
                    }
                },
                shortcut: nil
            ),
            MenuItem(
                title: "Toggle Panel Focus",
                icon: "arrow.left.arrow.right",
                action: {
                    guard let appState = AppStateProvider.shared else { return }
                    appState.toggleFocus()
                },
                hotKey: .togglePanelFocus
            ),
            MenuItem(
                title: "CD Tree…",
                icon: "list.triangle",
                action: stub("CD Tree…"),
                shortcut: "⌃D"
            ),
            MenuItem(
                title: "Branch View (With Subdirs)",
                icon: "arrow.triangle.branch",
                action: stub("Branch View"),
                shortcut: "⌃B"
            ),
        ])

// MARK: - Net Menu
    @MainActor
    let netMenuCategory = MenuCategory(
        title: "Net",
        icon: "globe",
        items: [
            MenuItem(
                title: "Connect to Server…",
                icon: "server.rack",
                action: { ConnectToServerCoordinator.shared.toggle() },
                hotKey: .connectToServer
            ),
            MenuItem(
                title: "Network Neighborhood",
                icon: "rectangle.connected.to.line.below",
                action: {
                    NetworkNeighborhoodCoordinator.shared.toggle()
                },
                hotKey: .networkNeighborhood
            ),
        ])

// MARK: - Show Menu
    @MainActor
    let showMenuCategory = MenuCategory(
        title: "Show",
        icon: "eye",
        items: [
            MenuItem(
                title: "Refresh Panels",
                icon: "arrow.triangle.2.circlepath",
                action: {
                    guard let appState = AppStateProvider.shared else { return }
                    appState.forceRefreshBothPanels()
                },
                hotKey: .refreshPanels
            ),
            MenuItem(
                title: "Show/Hide Hidden Files",
                icon: "eye.slash",
                action: {
                    UserPreferences.shared.snapshot.showHiddenFiles.toggle()
                    UserPreferences.shared.save()
                    guard let appState = AppStateProvider.shared else { return }
                    appState.forceRefreshBothPanels()
                },
                hotKey: .toggleHiddenFiles
            ),
        ])
