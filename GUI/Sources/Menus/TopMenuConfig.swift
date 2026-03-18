//
//  TopMenuConfig.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 13.03.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//  Description: Configuration, Start (Tabs), and Help menu categories.
//               Extracted from TopMenuMetadata.swift.

import AppKit
import Foundation

// MARK: - Configuration Menu
    @MainActor
    let configMenuCategory = MenuCategory(
        title: "Configuration",
        icon: "gearshape.2",
        items: [
            MenuItem(
                title: "Keyboard Shortcuts…",
                icon: "keyboard",
                action: { HotKeySettingsCoordinator.shared.showSettings() },
                hotKey: .openSettings
            ),
            MenuItem(
                title: "Customize Toolbar…",
                icon: "wrench.and.screwdriver",
                action: { ToolbarCustomizeCoordinator.shared.show() },
                shortcut: nil
            ),
        ])

// MARK: - Start (Tabs) Menu
    @MainActor
    let startMenuCategory = MenuCategory(
        title: "Start",
        icon: "play.circle",
        items: [
            MenuItem(
                title: "New Tab",
                icon: "plus.square",
                action: {
                    guard let appState = AppStateProvider.shared else { return }
                    let panel = appState.focusedPanel
                    let path = appState.path(for: panel)
                    _ = appState.tabManager(for: panel).addTab(url: URL(fileURLWithPath: path))
                },
                hotKey: .newTab
            ),
            MenuItem(
                title: "Duplicate Tab",
                icon: "plus.square.on.square",
                action: {
                    guard let appState = AppStateProvider.shared else { return }
                    let panel = appState.focusedPanel
                    let mgr = appState.tabManager(for: panel)
                    _ = mgr.duplicateTab(mgr.activeTab.id)
                },
                shortcut: "⌃D"
            ),
            MenuItem(
                title: "Close Tab",
                icon: "xmark.square",
                action: {
                    guard let appState = AppStateProvider.shared else { return }
                    appState.tabManager(for: appState.focusedPanel).closeActiveTab()
                },
                hotKey: .closeTab
            ),
            MenuItem(
                title: "Next Tab",
                icon: "arrow.right.square",
                action: {
                    guard let appState = AppStateProvider.shared else { return }
                    appState.tabManager(for: appState.focusedPanel).selectNextTab()
                },
                hotKey: .nextTab
            ),
            MenuItem(
                title: "Previous Tab",
                icon: "arrow.left.square",
                action: {
                    guard let appState = AppStateProvider.shared else { return }
                    appState.tabManager(for: appState.focusedPanel).selectPreviousTab()
                },
                hotKey: .prevTab
            ),
        ])

// MARK: - Help Menu
    @MainActor
    let helpMenuCategory = MenuCategory(
        title: "Help",
        icon: "questionmark.circle",
        items: [
            MenuItem(
                title: "Keyboard Shortcuts",
                icon: "keyboard",
                action: { HotKeySettingsCoordinator.shared.showSettings() },
                hotKey: .openSettings
            ),
            MenuItem(
                title: "Visit MimiNav Website",
                icon: "safari",
                action: {
                    if let url = URL(string: "https://github.com/senatov/MiMiNavigator") {
                        NSWorkspace.shared.open(url)
                    }
                },
                shortcut: nil
            ),
            MenuItem(
                title: "Check for Updates…",
                icon: "arrow.down.circle",
                action: { showUpdateWindow() },
                shortcut: nil
            ),
            MenuItem(
                title: "About MimiNav…",
                icon: "info.circle",
                action: { showAboutWindow() },
                shortcut: nil
            ),
        ])
