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
    titleStr: "Files",
    items: [
        MenuItem(title: "Open", action: { print("Open triggered") }, shortcut: "⌘O"),
        MenuItem(title: "Rename", action: { print("Rename triggered") }, shortcut: "⏎"),
        MenuItem(title: "Properties", action: { print("Properties shown") }, shortcut: "⌘I"),
    ]
)

@MainActor let markMenuCategory = MenuCategory(
    titleStr: "Mark",
    items: [
        MenuItem(title: "Select All", action: { print("All selected") }, shortcut: "⌘A"),
        MenuItem(title: "Unselect All", action: { print("Selection cleared") }, shortcut: "⌘⇧A"),
    ]
)

@MainActor let commandMenuCategory = MenuCategory(
    titleStr: "Command",
    items: [
        MenuItem(title: "Run", action: { print("Run command executed") }, shortcut: "⌘R"),
        MenuItem(title: "New Tab", action: { print("New tab opened") }, shortcut: "⌘T"),
    ]
)

@MainActor let netMenuCategory = MenuCategory(
    titleStr: "Net",
    items: [
        MenuItem(title: "Connect FTP", action: { print("FTP connected") }, shortcut: nil),
        MenuItem(title: "Disconnect", action: { print("Disconnected") }, shortcut: nil),
    ]
)

@MainActor let showMenuCategory = MenuCategory(
    titleStr: "Show",
    items: [
        MenuItem(title: "Hidden Files", action: { print("Toggled hidden files") }, shortcut: "⌘H")
    ]
)

@MainActor let configMenuCategory = MenuCategory(
    titleStr: "Config",
    items: [
        MenuItem(title: "Settings", action: { print("Settings opened") }, shortcut: "⌘,")
    ]
)

@MainActor let startMenuCategory = MenuCategory(
    titleStr: "Start",
    items: [
        MenuItem(title: "Reload", action: { print("App reloaded") }, shortcut: "⌘⇧R")
    ]
)

@MainActor let helpMenuCategory = MenuCategory(
    titleStr: "Help",
    items: [
        MenuItem(title: "Online Help", action: { print("Help shown") }, shortcut: "F1"),
        MenuItem(title: "About", action: { print("About shown") }, shortcut: nil),
    ]
)
