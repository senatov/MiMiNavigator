//
//  TopMenuBarView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 16.10.24.
//  Description: SwiftUI component for rendering the top menu bar with dropdown menus and shortcuts.
//

import SwiftUI

struct TopMenuBarView: View {
    @Binding var isShowMenu: Bool  // Toggle state for showing/hiding menu
    var toggleMenu: () -> Void  // Action to toggle the menu

    var body: some View {
        HStack(spacing: 8) {
            // Left-side menu button with a hamburger icon
            Button(action: toggleMenu) {
                HStack {
                    Image(systemName: "line.horizontal.3")  // Classic hamburger menu icon
                    Text("")
                }
                .accessibilityLabel("Toggle")
                .background(Color.clear.opacity(0.1))
            }
            .background(Color.clear.opacity(0.1))

            // Dynamically generate menus based on `menuData`
            ForEach(menuData) { menu in
                Menu {
                    // Populate each menu category with its items
                    ForEach(menu.items) { item in
                        Button(action: item.action) {
                            HStack {
                                Text(item.title)  // Menu item title
                                Spacer()
                                // Add a shortcut label if defined
                                if let shortcut = item.shortcut {
                                    Text(shortcut).foregroundColor(.gray)
                                }
                            }
                        }
                    }
                } label: {
                    Text(menu.title)
                        .padding(.horizontal, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.clear.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            .background(Color.clear.opacity(0.1))
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }

    // MARK: - Menu Data (Fake Data Layer)
    private var menuData: [MenuCategory] {
        // Hardcoding menu categories (like an old-school `switchboard`)
        [
            filesMenuCategory,
            markMenuCategory,
            commandMenuCategory,
            netMenuCategory,
            showMenuCategory,
            configMenuCategory,
            startMenuCategory,
            helpMenuCategory,
        ]
    }

    // MARK: - File Menu (Your bread-and-butter file ops)
    private var filesMenuCategory: MenuCategory {
        MenuCategory(title: "Files", items: filesMenuItems)
    }

    private var filesMenuItems: [MenuItem] {
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
    private var markMenuCategory: MenuCategory {
        MenuCategory(title: "Mark", items: markMenuItems)
    }

    private var markMenuItems: [MenuItem] {
        [
            .init(title: "Select Group...", action: {}, shortcut: "Num+"),
            .init(title: "Unselect Group...", action: {}, shortcut: "Num-"),
            .init(title: "Select All", action: {}, shortcut: "Ctrl+A"),
            .init(title: "Unselect All", action: {}, shortcut: "Ctrl+U"),
            .init(title: "Invert Selection", action: {}, shortcut: nil),
        ]
    }

    // MARK: - Command Menu (CMD-style actions)
    private var commandMenuCategory: MenuCategory {
        MenuCategory(title: "Commands", items: commandMenuItems)
    }

    private var commandMenuItems: [MenuItem] {
        [
            .init(title: "Open Command Prompt...", action: {}, shortcut: "Ctrl+P"),
            .init(title: "Open Desktop Folder", action: {}, shortcut: nil),
            .init(title: "CD Tree...", action: {}, shortcut: "Ctrl+D"),
            .init(title: "Branch View (With Subdirs)", action: {}, shortcut: "Ctrl+B"),
        ]
    }

    // MARK: - Net Menu (The web stuff, FTP, etc.)
    private var netMenuCategory: MenuCategory {
        MenuCategory(title: "Net", items: netMenuItems)
    }

    private var netMenuItems: [MenuItem] {
        [
            .init(title: "FTP Connect...", action: {}, shortcut: "Ctrl+N"),
            .init(title: "FTP Disconnect", action: {}, shortcut: nil),
            .init(title: "Network Neighborhood", action: {}, shortcut: nil),
        ]
    }

    // MARK: - Show Menu (View-related options)
    private var showMenuCategory: MenuCategory {
        MenuCategory(title: "Show", items: showMenuItems)
    }

    private var showMenuItems: [MenuItem] {
        [
            .init(title: "Full View", action: {}, shortcut: nil),
            .init(title: "Brief View", action: {}, shortcut: nil),
            .init(title: "Hidden Files", action: {}, shortcut: "Ctrl+H"),
        ]
    }

    // MARK: - Configuration Menu (The power user’s playground)
    private var configMenuCategory: MenuCategory {
        MenuCategory(title: "Configuration", items: configMenuItems)
    }

    private var configMenuItems: [MenuItem] {
        [
            .init(title: "Options...", action: {}, shortcut: "Alt+O"),
            .init(title: "Customize Toolbar...", action: {}, shortcut: nil),
        ]
    }

    // MARK: - Start Menu (Tabs and layout management)
    private var startMenuCategory: MenuCategory {
        MenuCategory(title: "Start", items: startMenuItems)
    }

    private var startMenuItems: [MenuItem] {
        [
            .init(title: "New Tab", action: {}, shortcut: "Ctrl+T"),
            .init(title: "Duplicate Tab", action: {}, shortcut: "Ctrl+D"),
            .init(title: "Close Tab", action: {}, shortcut: "Ctrl+W"),
        ]
    }

    // MARK: - Help Menu (Docs, guides, updates)
    private var helpMenuCategory: MenuCategory {
        MenuCategory(title: "Help", items: helpMenuItems)
    }

    private var helpMenuItems: [MenuItem] {
        [
            .init(title: "Contents", action: {}, shortcut: "F1"),
            .init(title: "Keyboard Shortcuts", action: {}, shortcut: nil),
            .init(title: "Check for Updates...", action: {}, shortcut: nil),
        ]
    }
}
