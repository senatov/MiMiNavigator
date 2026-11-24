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
                        await CntMenuCoord.shared.performCompress(
                            files: files,
                            archiveName: "",
                            destination: destinationURL,
                            moveToArchive: false,
                            appState: appState
                        )
                    }
                },
                hotKey: .packFiles,
                isEnabled: {
                    guard let appState = AppStateProvider.shared else { return false }
                    return !appState.filesForOperation(on: appState.focusedPanel).isEmpty
                }
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
                hotKey: .unpackFiles,
                isEnabled: { false }
            ),
            MenuItem(
                title: "Test Archive(s)",
                icon: "checkmark.shield",
                action: stub("Test Archive(s)"),
                shortcut: nil,
                isEnabled: { false }
            ),
            MenuItem(
                title: "Compare By Content…",
                icon: "doc.text.magnifyingglass",
                action: stub("Compare By Content…"),
                hotKey: .compareContent,
                isEnabled: { false }
            ),
            MenuItem(
                title: "Synchronize Directories…",
                icon: "arrow.triangle.2.circlepath",
                action: stub("Synchronize Directories…"),
                hotKey: .syncDirectories,
                isEnabled: { false }
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
                hotKey: .markByPattern,
                isEnabled: {
                    guard let appState = AppStateProvider.shared else { return false }
                    return !appState.displayedFiles(for: appState.focusedPanel).isEmpty
                }
            ),
            MenuItem(
                title: "Unselect Group…",
                icon: "minus.circle",
                action: {
                    guard let appState = AppStateProvider.shared else { return }
                    appState.unmarkByPattern()
                },
                hotKey: .unmarkByPattern,
                isEnabled: {
                    guard let appState = AppStateProvider.shared else { return false }
                    return !appState.markedFiles(for: appState.focusedPanel).isEmpty
                }
            ),
            MenuItem(
                title: "Select All",
                icon: "checkmark.circle.fill",
                action: {
                    guard let appState = AppStateProvider.shared else { return }
                    appState.markAll()
                },
                hotKey: .markAll,
                isEnabled: {
                    guard let appState = AppStateProvider.shared else { return false }
                    return !appState.displayedFiles(for: appState.focusedPanel).isEmpty
                }
            ),
            MenuItem(
                title: "Unselect All",
                icon: "circle",
                action: {
                    guard let appState = AppStateProvider.shared else { return }
                    appState.unmarkAll()
                },
                hotKey: .unmarkAll,
                isEnabled: {
                    guard let appState = AppStateProvider.shared else { return false }
                    return !appState.markedFiles(for: appState.focusedPanel).isEmpty
                }
            ),
            MenuItem(
                title: "Invert Selection",
                icon: "arrow.triangle.swap",
                action: {
                    guard let appState = AppStateProvider.shared else { return }
                    appState.invertMarks()
                },
                hotKey: .invertMarks,
                isEnabled: {
                    guard let appState = AppStateProvider.shared else { return false }
                    return !appState.displayedFiles(for: appState.focusedPanel).isEmpty
                }
            ),
            MenuItem(
                title: "Select Same Extension",
                icon: "doc.badge.ellipsis",
                action: {
                    guard let appState = AppStateProvider.shared else { return }
                    appState.markSameExtension()
                },
                hotKey: .markSameExtension,
                isEnabled: {
                    guard let appState = AppStateProvider.shared else { return false }
                    return !appState.filesForOperation(on: appState.focusedPanel).isEmpty
                }
            ),
        ])
