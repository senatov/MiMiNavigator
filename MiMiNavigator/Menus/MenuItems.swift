//
//  MenuItems.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 01.06.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import Foundation

// MARK: - File Menu
@MainActor
let filesMenuCategory = MenuCategory(
    title: "Files",
    items: [
        MenuItem(title: "Rename/Move", action: { log.debug("Menu > Files > Rename/Move") }, shortcut: "F6"),
        MenuItem(title: "Change Attributes...", action: { log.debug("Menu > Files > Change Attributes...") }, shortcut: "Ctrl+A"),
        MenuItem(title: "Pack...", action: { log.debug("Menu > Files > Pack...") }, shortcut: "Alt+F5"),
        MenuItem(title: "Unpack...", action: { log.debug("Menu > Files > Unpack...") }, shortcut: "Alt+F9"),
        MenuItem(title: "Test Archive(s)", action: { log.debug("Menu > Files > Test Archive(s)") }, shortcut: nil),
        MenuItem(
            title: "Compare By Content...", action: { log.debug("Menu > Files > Compare By Content...") }, shortcut: "Ctrl+C"),
        MenuItem(
            title: "Synchronize Directories...", action: { log.debug("Menu > Files > Synchronize Directories...") },
            shortcut: "Ctrl+S"),
        MenuItem(title: "Quit", action: { log.debug("Menu > Files > Quit") }, shortcut: "Alt+F4"),
    ])

// MARK: - Mark Menu
@MainActor
let markMenuCategory = MenuCategory(
    title: "Mark",
    items: [
        MenuItem(title: "Select Group...", action: { log.debug("Menu > Mark > Select Group...") }, shortcut: "Num+"),
        MenuItem(title: "Unselect Group...", action: { log.debug("Menu > Mark > Unselect Group...") }, shortcut: "Num-"),
        MenuItem(title: "Select All", action: { log.debug("Menu > Mark > Select All") }, shortcut: "Ctrl+A"),
        MenuItem(title: "Unselect All", action: { log.debug("Menu > Mark > Unselect All") }, shortcut: "Ctrl+U"),
        MenuItem(title: "Invert Selection", action: { log.debug("Menu > Mark > Invert Selection") }, shortcut: nil),
    ])

// MARK: - Commands Menu
@MainActor
let commandMenuCategory = MenuCategory(
    title: "Commands",
    items: [
        MenuItem(
            title: "Open Command Prompt...", action: { log.debug("Menu > Commands > Open Command Prompt...") }, shortcut: "Ctrl+P"
        ),
        MenuItem(title: "Open Desktop Folder", action: { log.debug("Menu > Commands > Open Desktop Folder") }, shortcut: nil),
        MenuItem(title: "CD Tree...", action: { log.debug("Menu > Commands > CD Tree...") }, shortcut: "Ctrl+D"),
        MenuItem(
            title: "Branch View (With Subdirs)", action: { log.debug("Menu > Commands > Branch View (With Subdirs)") },
            shortcut: "Ctrl+B"),
    ])

// MARK: - Net Menu
@MainActor
let netMenuCategory = MenuCategory(
    title: "Net",
    items: [
        MenuItem(title: "FTP Connect...", action: { log.debug("Menu > Net > FTP Connect...") }, shortcut: "Ctrl+N"),
        MenuItem(title: "FTP Disconnect", action: { log.debug("Menu > Net > FTP Disconnect") }, shortcut: nil),
        MenuItem(title: "Network Neighborhood", action: { log.debug("Menu > Net > Network Neighborhood") }, shortcut: nil),
    ])

// MARK: - Show Menu
@MainActor
let showMenuCategory = MenuCategory(
    title: "Show",
    items: [
        MenuItem(title: "Full View", action: { log.debug("Menu > Show > Full View") }, shortcut: nil),
        MenuItem(title: "Brief View", action: { log.debug("Menu > Show > Brief View") }, shortcut: nil),
        MenuItem(title: "Hidden Files", action: { log.debug("Menu > Show > Hidden Files") }, shortcut: "Ctrl+H"),
    ])

// MARK: - Configuration Menu
@MainActor
let configMenuCategory = MenuCategory(
    title: "Configuration",
    items: [
        MenuItem(title: "Options...", action: { log.debug("Menu > Configuration > Options...") }, shortcut: "Alt+O"),
        MenuItem(
            title: "Customize Toolbar...", action: { log.debug("Menu > Configuration > Customize Toolbar...") }, shortcut: nil),
    ])

// MARK: - Start Menu
@MainActor
let startMenuCategory = MenuCategory(
    title: "Start",
    items: [
        MenuItem(title: "New Tab", action: { log.debug("Menu > Start > New Tab") }, shortcut: "Ctrl+T"),
        MenuItem(title: "Duplicate Tab", action: { log.debug("Menu > Start > Duplicate Tab") }, shortcut: "Ctrl+D"),
        MenuItem(title: "Close Tab", action: { log.debug("Menu > Start > Close Tab") }, shortcut: "Ctrl+W"),
    ])

// MARK: - Help Menu
@MainActor
let helpMenuCategory = MenuCategory(
    title: "Help",
    items: [
        MenuItem(title: "Index", action: { log.debug("Help > Index") }, shortcut: "F1"),
        MenuItem(title: "Keyboard", action: { log.debug("Help > Keyboard") }, shortcut: nil),
        MenuItem(title: "Registration Info", action: { log.debug("Help > Registration Info") }, shortcut: nil),
        MenuItem(title: "Visit MimiNav Website", action: { log.debug("Help > Website") }, shortcut: nil),
        MenuItem(title: "Check for Updates", action: { log.debug("Help > Check for Updates") }, shortcut: nil),
        MenuItem(title: "About MimiNav…", action: { log.debug("Help > About MimiNav") }, shortcut: nil),
    ])
