// TopMenuMetadata.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 01.06.2025.
// Copyright © 2025-2026 Senatov. All rights reserved.
// Description: Menu item metadata — real actions where implemented, stub popups elsewhere.
//   Items with HotKeyAction use live shortcut display from HotKeyStore.

import AppKit
import Foundation

// MARK: - Stub popup helper
@MainActor
private func stub(_ title: String) -> @MainActor @Sendable () -> Void {
    {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = "This feature is not yet implemented."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

// MARK: - Files Menu
@MainActor
let filesMenuCategory = MenuCategory(
    title: "Files",
    icon: "doc.on.doc",
    items: [
        MenuItem(
            title: "Pack…",
            icon: "archivebox",
            action: {
                guard let appState = AppStateProvider.shared else { return }
                let panel = appState.focusedPanel
                let files = appState.filesForOperation(on: panel)
                guard !files.isEmpty else { stub("Pack…: select or mark files first")(); return }
                Task { await ContextMenuCoordinator.shared.performCompress(files: files, appState: appState) }
            },
            shortcut: "⌥F5"
        ),
        MenuItem(
            title: "Settings…",
            icon: "gearshape",
            action: { SettingsCoordinator.shared.toggle() },
            shortcut: "⌘,"
        ),
        MenuItem(
            title: "Unpack…",
            icon: "archivebox.fill",
            action: stub("Unpack…"),
            shortcut: "⌥F9"
        ),
        MenuItem(
            title: "Test Archive(s)",
            icon: "checkmark.shield",
            action: stub("Test Archive(s)"),
            shortcut: nil
        ),
        MenuItem(
            title: "Compare By Content…",
            icon: "doc.text.magnifyingglass",
            action: stub("Compare By Content…"),
            shortcut: "⌃C"
        ),
        MenuItem(
            title: "Synchronize Directories…",
            icon: "arrow.triangle.2.circlepath",
            action: stub("Synchronize Directories…"),
            shortcut: "⌃S"
        ),
        MenuItem(
            title: "Quit",
            icon: "power",
            action: { NSApplication.shared.terminate(nil) },
            hotKey: .exitApp
        ),
    ])

// MARK: - Mark Menu
@MainActor
let markMenuCategory = MenuCategory(
    title: "Mark",
    icon: "checkmark.circle",
    items: [
        MenuItem(
            title: "Select Group…",
            icon: "plus.circle",
            action: {
                guard let appState = AppStateProvider.shared else { return }
                appState.markByPattern()
            },
            hotKey: .markByPattern
        ),
        MenuItem(
            title: "Unselect Group…",
            icon: "minus.circle",
            action: {
                guard let appState = AppStateProvider.shared else { return }
                appState.unmarkByPattern()
            },
            hotKey: .unmarkByPattern
        ),
        MenuItem(
            title: "Select All",
            icon: "checkmark.circle.fill",
            action: {
                guard let appState = AppStateProvider.shared else { return }
                appState.markAll()
            },
            hotKey: .markAll
        ),
        MenuItem(
            title: "Unselect All",
            icon: "circle",
            action: {
                guard let appState = AppStateProvider.shared else { return }
                appState.unmarkAll()
            },
            hotKey: .unmarkAll
        ),
        MenuItem(
            title: "Invert Selection",
            icon: "arrow.triangle.swap",
            action: {
                guard let appState = AppStateProvider.shared else { return }
                appState.invertMarks()
            },
            hotKey: .invertMarks
        ),
        MenuItem(
            title: "Select Same Extension",
            icon: "doc.badge.ellipsis",
            action: {
                guard let appState = AppStateProvider.shared else { return }
                appState.markSameExtension()
            },
            hotKey: .markSameExtension
        ),
    ])

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
                let path = panel == .left ? appState.leftPath : appState.rightPath
                let file = panel == .left ? appState.selectedLeftFile : appState.selectedRightFile
                FindFilesCoordinator.shared.toggle(searchPath: path, selectedFile: file)
            },
            hotKey: .findFiles
        ),
        MenuItem(
            title: "Open in Terminal",
            icon: "apple.terminal",
            action: {
                guard let appState = AppStateProvider.shared else { return }
                let panel = appState.focusedPanel
                let path = panel == .left ? appState.leftPath : appState.rightPath
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
                let path = panel == .left ? appState.leftPath : appState.rightPath
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
            shortcut: "⌃N"
        ),
        MenuItem(
            title: "Network Neighborhood",
            icon: "rectangle.connected.to.line.below",
            action: {
                NetworkNeighborhoodCoordinator.shared.toggle()
            },
            shortcut: nil
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
            title: "Options…",
            icon: "slider.horizontal.3",
            action: stub("Options…"),
            shortcut: "⌥O"
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
                let path = panel == .left ? appState.leftPath : appState.rightPath
                _ = appState.tabManager(for: panel).addTab(path: path)
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
            shortcut: "F1"
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
            action: stub("Check for Updates…"),
            shortcut: nil
        ),
        MenuItem(
            title: "About MimiNav…",
            icon: "info.circle",
            action: stub("About MimiNav…"),
            shortcut: nil
        ),
    ])
