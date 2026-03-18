//
//  TopMenuFilesMark.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 13.03.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//  Description: Files and Mark menu categories.
//               Extracted from TopMenuMetadata.swift.

import AppKit
import Foundation

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
                    Task {
                        let destinationURL = appState.url(for: panel)
                        await ContextMenuCoordinator.shared.performCompress(
                            files: files,
                            archiveName: "",
                            destination: destinationURL,
                            moveToArchive: false,
                            appState: appState
                        )
                    }
                },
                shortcut: "⌥F5"
            ),
            MenuItem(
                title: "Settings…",
                icon: "gearshape",
                action: { SettingsCoordinator.shared.toggle() },
                hotKey: .openSettings
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
