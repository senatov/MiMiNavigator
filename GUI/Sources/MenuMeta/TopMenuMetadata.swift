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
    items: [
        MenuItem(
            title: "Pack…",
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
            title: "Unpack…",
            action: stub("Unpack…"),
            shortcut: "⌥F9"
        ),
        MenuItem(
            title: "Test Archive(s)",
            action: stub("Test Archive(s)"),
            shortcut: nil
        ),
        MenuItem(
            title: "Compare By Content…",
            action: stub("Compare By Content…"),
            shortcut: "⌃C"
        ),
        MenuItem(
            title: "Synchronize Directories…",
            action: stub("Synchronize Directories…"),
            shortcut: "⌃S"
        ),
        MenuItem(
            title: "Settings…",
            action: { SettingsCoordinator.shared.toggle() },
            shortcut: "⌘,"
        ),
        MenuItem(
            title: "Quit",
            action: { NSApplication.shared.terminate(nil) },
            hotKey: .exitApp
        ),
    ])

// MARK: - Mark Menu
@MainActor
let markMenuCategory = MenuCategory(
    title: "Mark",
    items: [
        MenuItem(
            title: "Select Group…",
            action: {
                guard let appState = AppStateProvider.shared else { return }
                appState.markByPattern()
            },
            hotKey: .markByPattern
        ),
        MenuItem(
            title: "Unselect Group…",
            action: {
                guard let appState = AppStateProvider.shared else { return }
                appState.unmarkByPattern()
            },
            hotKey: .unmarkByPattern
        ),
        MenuItem(
            title: "Select All",
            action: {
                guard let appState = AppStateProvider.shared else { return }
                appState.markAll()
            },
            hotKey: .markAll
        ),
        MenuItem(
            title: "Unselect All",
            action: {
                guard let appState = AppStateProvider.shared else { return }
                appState.unmarkAll()
            },
            hotKey: .unmarkAll
        ),
        MenuItem(
            title: "Invert Selection",
            action: {
                guard let appState = AppStateProvider.shared else { return }
                appState.invertMarks()
            },
            hotKey: .invertMarks
        ),
        MenuItem(
            title: "Select Same Extension",
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
    items: [
        MenuItem(
            title: "Find Files…",
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
            action: {
                guard let appState = AppStateProvider.shared else { return }
                appState.toggleFocus()
            },
            hotKey: .togglePanelFocus
        ),
        MenuItem(
            title: "CD Tree…",
            action: stub("CD Tree…"),
            shortcut: "⌃D"
        ),
        MenuItem(
            title: "Branch View (With Subdirs)",
            action: stub("Branch View"),
            shortcut: "⌃B"
        ),
    ])

// MARK: - Net Menu
@MainActor
let netMenuCategory = MenuCategory(
    title: "Net",
    items: [
        MenuItem(
            title: "Connect to Server…",
            action: { ConnectToServerCoordinator.shared.toggle() },
            shortcut: "⌃N"
        ),
        MenuItem(
            title: "Network Neighborhood",
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
    items: [
        MenuItem(
            title: "Refresh Panels",
            action: {
                guard let appState = AppStateProvider.shared else { return }
                appState.forceRefreshBothPanels()
            },
            hotKey: .refreshPanels
        ),
        MenuItem(
            title: "Show/Hide Hidden Files",
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
    items: [
        MenuItem(
            title: "Keyboard Shortcuts…",
            action: { HotKeySettingsCoordinator.shared.showSettings() },
            hotKey: .openSettings
        ),
        MenuItem(title: "Options…",            action: stub("Options…"),            shortcut: "⌥O"),
        MenuItem(title: "Customize Toolbar…",  action: { ToolbarCustomizeCoordinator.shared.show() },  shortcut: nil),
    ])

// MARK: - Start (Tabs) Menu
@MainActor
let startMenuCategory = MenuCategory(
    title: "Start",
    items: [
        MenuItem(
            title: "New Tab",
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
            action: {
                guard let appState = AppStateProvider.shared else { return }
                appState.tabManager(for: appState.focusedPanel).closeActiveTab()
            },
            hotKey: .closeTab
        ),
        MenuItem(
            title: "Next Tab",
            action: {
                guard let appState = AppStateProvider.shared else { return }
                appState.tabManager(for: appState.focusedPanel).selectNextTab()
            },
            hotKey: .nextTab
        ),
        MenuItem(
            title: "Previous Tab",
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
    items: [
        MenuItem(title: "Keyboard Shortcuts",    action: { HotKeySettingsCoordinator.shared.showSettings() }, shortcut: "F1"),
        MenuItem(title: "Visit MimiNav Website", action: {
            if let url = URL(string: "https://github.com/senatov/MiMiNavigator") {
                NSWorkspace.shared.open(url)
            }
        }, shortcut: nil),
        MenuItem(title: "Check for Updates…", action: stub("Check for Updates…"), shortcut: nil),
        MenuItem(title: "About MimiNav…",     action: stub("About MimiNav…"),     shortcut: nil),
    ])
