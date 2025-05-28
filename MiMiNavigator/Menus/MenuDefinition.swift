//
//  MenuDefinition.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 28.05.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import Foundation

/// Defines all static top-level menus for the app.
@MainActor let filesMenuCategory = MenuCategory(
    title: "Files",
    items: [
        MenuItem(title: "Open", action: { print("Open triggered") }, shortcut: "⌘O"),
        MenuItem(title: "Rename", action: { print("Rename triggered") }, shortcut: "⏎"),
        MenuItem(title: "Properties", action: { print("Properties shown") }, shortcut: "⌘I"),
    ]
)

@MainActor let markMenuCategory = MenuCategory(
    title: "Mark",
    items: [
        MenuItem(title: "Select All", action: { print("All selected") }, shortcut: "⌘A"),
        MenuItem(title: "Unselect All", action: { print("Selection cleared") }, shortcut: "⌘⇧A"),
    ]
)

@MainActor let commandMenuCategory = MenuCategory(
    title: "Command",
    items: [
        MenuItem(title: "Run", action: { print("Run command executed") }, shortcut: "⌘R"),
        MenuItem(title: "New Tab", action: { print("New tab opened") }, shortcut: "⌘T"),
    ]
)

@MainActor let netMenuCategory = MenuCategory(
    title: "Net",
    items: [
        MenuItem(title: "Connect FTP", action: { print("FTP connected") }, shortcut: nil),
        MenuItem(title: "Disconnect", action: { print("Disconnected") }, shortcut: nil),
    ]
)

@MainActor let showMenuCategory = MenuCategory(
    title: "Show",
    items: [
        MenuItem(title: "Hidden Files", action: { print("Toggled hidden files") }, shortcut: "⌘H")
    ]
)

@MainActor let configMenuCategory = MenuCategory(
    title: "Config",
    items: [
        MenuItem(title: "Settings", action: { print("Settings opened") }, shortcut: "⌘,")
    ]
)

@MainActor let startMenuCategory = MenuCategory(
    title: "Start",
    items: [
        MenuItem(title: "Reload", action: { print("App reloaded") }, shortcut: "⌘⇧R")
    ]
)

@MainActor let helpMenuCategory = MenuCategory(
    title: "Help",
    items: [
        MenuItem(title: "Online Help", action: { print("Help shown") }, shortcut: "F1"),
        MenuItem(title: "About", action: { print("About shown") }, shortcut: nil),
    ]
)
