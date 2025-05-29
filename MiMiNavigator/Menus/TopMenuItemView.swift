//
//  MenuItemView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 18.02.25.
//  Copyright © 2025 Senatov. All rights reserved.
//

import SwiftUI

/// Represents an individual item in a dropdown menu
struct TopMenuItemView: View {
    let item: MenuItem
    @State private var isHovered = false
    @State private var showHelpText = false
    // MARK: -
    var body: some View {
        Button(action: performAction) {
            HStack {
                Text(item.title)
                Spacer()
                if let shortcut = item.shortcut {
                    Text(shortcut)
                        .foregroundColor(.gray)
                        .font(.caption)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(backgroundColor)
            .cornerRadius(7)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover(perform: handleHover)
        .popover(
            isPresented: $showHelpText,
            attachmentAnchor: .point(.trailing),
            arrowEdge: .leading
        ) {
            HelpPopup(text: "This is a help text for \(item.title).")
        }
    }

    // MARK: - Computed Background
    private var backgroundColor: Color {
        isHovered ? Color.blue.opacity(0.3) : Color.clear
    }

    // MARK: - Actions
    private func performAction() {
        item.action()
    }
    // MARK: -
    private func handleHover(_ hovering: Bool) {
        isHovered = hovering
        if hovering {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if isHovered {
                    showHelpText = true
                }
            }
        } else {
            showHelpText = false
        }
    }
}

// MARK: - File Menu (Your bread-and-butter file ops)
var filesMenuCategoryTop: MenuCategory {
    MenuCategory(titleStr: "Files", items: filesMenuItems)
}

// MARK: -
var filesMenuItems: [MenuItem] {
    [
        .init(title: "Rename/Move", action: {}, shortcut: "F6"),
        .init(title: "Change Attributes...", action: {}, shortcut: "Ctrl+A"),
        .init(title: "Pack...", action: {}, shortcut: "Alt+F5"),
        .init(title: "Unpack...", action: {}, shortcut: "Alt+F9"),
        .init(title: "Test Archive(s)", action: {}, shortcut: nil),
        .init(title: "Compare By Content...", action: {}, shortcut: "Ctrl+C"),
        .init(title: "Synchronize Directories...", action: {}, shortcut: "Ctrl+S"),
        .init(title: "Quit", action: {}, shortcut: "Alt+F4"),
    ]
}

// MARK: - Mark Menu (Select, unselect... the basics)
var markMenuCategoryTop: MenuCategory {
    MenuCategory(titleStr: "Mark", items: markMenuItems)
}

var markMenuItems: [MenuItem] {
    [
        .init(title: "Select Group...", action: {}, shortcut: "Num+"),
        .init(title: "Unselect Group...", action: {}, shortcut: "Num-"),
        .init(title: "Select All", action: {}, shortcut: "Ctrl+A"),
        .init(title: "Unselect All", action: {}, shortcut: "Ctrl+U"),
        .init(title: "Invert Selection", action: {}, shortcut: nil),
    ]
}

// MARK: - Command Menu (CMD-style actions)
var commandMenuCategoryTop: MenuCategory {
    MenuCategory(titleStr: "Commands", items: commandMenuItems)
}

// MARK: -
var commandMenuItems: [MenuItem] {
    [
        .init(title: "Open Command Prompt...", action: {}, shortcut: "Ctrl+P"),
        .init(title: "Open Desktop Folder", action: {}, shortcut: nil),
        .init(title: "CD Tree...", action: {}, shortcut: "Ctrl+D"),
        .init(title: "Branch View (With Subdirs)", action: {}, shortcut: "Ctrl+B"),
    ]
}

// MARK: - Net Menu (The web stuff, FTP, etc.)
var netMenuCategoryTop: MenuCategory {
    MenuCategory(titleStr: "Net", items: netMenuItems)
}

// MARK: -
var netMenuItems: [MenuItem] {
    [
        .init(title: "FTP Connect...", action: {}, shortcut: "Ctrl+N"),
        .init(title: "FTP Disconnect", action: {}, shortcut: nil),
        .init(title: "Network Neighborhood", action: {}, shortcut: nil),
    ]
}

// MARK: - Show Menu (View-related options)
var showMenuCategoryTop: MenuCategory {
    MenuCategory(titleStr: "Show", items: showMenuItems)
}

var showMenuItems: [MenuItem] {
    [
        .init(title: "Full View", action: {}, shortcut: nil),
        .init(title: "Brief View", action: {}, shortcut: nil),
        .init(title: "Hidden Files", action: {}, shortcut: "Ctrl+H"),
    ]
}

// MARK: - Configuration Menu (The power user’s playground)
var configMenuCategoryTop: MenuCategory {
    MenuCategory(titleStr: "Configuration", items: configMenuItems)
}

var configMenuItems: [MenuItem] {
    [
        .init(title: "Options...", action: {}, shortcut: "Alt+O"),
        .init(title: "Customize Toolbar...", action: {}, shortcut: nil),
    ]
}

// MARK: - Start Menu (Tabs and layout management)
var startMenuCategoryTop: MenuCategory {
    MenuCategory(titleStr: "Start", items: startMenuItems)
}

var startMenuItems: [MenuItem] {
    [
        .init(title: "New Tab", action: {}, shortcut: "Ctrl+T"),
        .init(title: "Duplicate Tab", action: {}, shortcut: "Ctrl+D"),
        .init(title: "Close Tab", action: {}, shortcut: "Ctrl+W"),
    ]
}

// MARK: - Help Menu (Docs, guides, updates)
var helpMenuCategoryTop: MenuCategory {
    MenuCategory(titleStr: "Help", items: helpMenuItems)
}

var helpMenuItems: [MenuItem] {
    [
        .init(title: "Contents", action: {}, shortcut: "F1"),
        .init(title: "Keyboard Shortcuts", action: {}, shortcut: nil),
        .init(title: "Check for Updates...", action: {}, shortcut: nil),
    ]
}

struct HelpPopup: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundColor(.black)
            .padding(8)
            .background(Color.yellow.opacity(0.1))  // Бледно-жёлтый фон
            .cornerRadius(7)
            .frame(width: 200)  // Ограничение ширины
    }
}



