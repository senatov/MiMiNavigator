// TopMenuMetadata.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 01.06.2025.
// Copyright © 2025-2026 Senatov. All rights reserved.
// Description: Menu item metadata — real actions where implemented, stub popups elsewhere

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
            title: "Quit",
            action: { NSApplication.shared.terminate(nil) },
            shortcut: "⌥F4"
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
            shortcut: "Num+"
        ),
        MenuItem(
            title: "Unselect Group…",
            action: {
                guard let appState = AppStateProvider.shared else { return }
                appState.unmarkByPattern()
            },
            shortcut: "Num-"
        ),
        MenuItem(
            title: "Select All",
            action: {
                guard let appState = AppStateProvider.shared else { return }
                appState.markAll()
            },
            shortcut: "⌃A"
        ),
        MenuItem(
            title: "Unselect All",
            action: {
                guard let appState = AppStateProvider.shared else { return }
                appState.unmarkAll()
            },
            shortcut: "⌃U"
        ),
        MenuItem(
            title: "Invert Selection",
            action: {
                guard let appState = AppStateProvider.shared else { return }
                appState.invertMarks()
            },
            shortcut: nil
        ),
        MenuItem(
            title: "Select Same Extension",
            action: {
                guard let appState = AppStateProvider.shared else { return }
                appState.markSameExtension()
            },
            shortcut: nil
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
            shortcut: "⌥F7"
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
            shortcut: "⌘⌥T"
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
                guard let appState = AppStateProvider.shared else { return }
                appState.showNetworkNeighborhood = true
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
            title: "Refresh Panel",
            action: {
                guard let appState = AppStateProvider.shared else { return }
                let panel = appState.focusedPanel
                ContextMenuCoordinator.shared.refreshPanel(panel, appState: appState)
            },
            shortcut: "⌃R"
        ),
        MenuItem(
            title: "Show/Hide Hidden Files",
            action: {
                UserPreferences.shared.snapshot.showHiddenFiles.toggle()
                UserPreferences.shared.save()
            },
            shortcut: "⌃H"
        ),
        MenuItem(title: "Full View",  action: stub("Full View"),  shortcut: nil),
        MenuItem(title: "Brief View", action: stub("Brief View"), shortcut: nil),
    ])

// MARK: - Configuration Menu
@MainActor
let configMenuCategory = MenuCategory(
    title: "Configuration",
    items: [
        MenuItem(
            title: "Keyboard Shortcuts…",
            action: { HotKeySettingsCoordinator.shared.showSettings() },
            shortcut: "⌘,"
        ),
        MenuItem(title: "Options…",            action: stub("Options…"),            shortcut: "⌥O"),
        MenuItem(title: "Customize Toolbar…",  action: stub("Customize Toolbar…"),  shortcut: nil),
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
            shortcut: "⌃T"
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
            shortcut: "⌃W"
        ),
        MenuItem(
            title: "Next Tab",
            action: {
                guard let appState = AppStateProvider.shared else { return }
                appState.tabManager(for: appState.focusedPanel).selectNextTab()
            },
            shortcut: "⌃⇥"
        ),
        MenuItem(
            title: "Previous Tab",
            action: {
                guard let appState = AppStateProvider.shared else { return }
                appState.tabManager(for: appState.focusedPanel).selectPreviousTab()
            },
            shortcut: "⌃⇧⇥"
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
