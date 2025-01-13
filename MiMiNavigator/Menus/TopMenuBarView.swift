//
//  TopMenuBarView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 16.10.24.
//

import SwiftUI

struct TopMenuBarView: View {
    @Binding var isShowMenu: Bool
    var toggleMenu: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(menuData) { menu in
                Menu {
                    ForEach(menu.items) { item in
                        Button(action: item.action) {
                            Text(item.title)
                            if let shortcut = item.shortcut {
                                Spacer()
                                Text(shortcut).foregroundColor(.gray)
                            }
                        }
                    }
                } label: {
                    Text(menu.title)
                        .padding(.horizontal, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }

    // MARK: - Menu Data
    private var menuData: [MenuCategory] {
        [
            MenuCategory(title: "Files", items: filesMenuItems),
            MenuCategory(title: "Mark", items: markMenuItems),
            MenuCategory(title: "Commands", items: commandMenuItems),
            MenuCategory(title: "Net", items: netMenuItems),
            MenuCategory(title: "Show", items: showMenuItems),
            MenuCategory(title: "Configuration", items: configMenuItems),
            MenuCategory(title: "Start", items: startMenuItems),
            MenuCategory(title: "Help", items: helpMenuItems),
        ]
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

    private var markMenuItems: [MenuItem] {
        [
            .init(title: "Select Group...", action: {}, shortcut: "Num+"),
            .init(title: "Unselect Group...", action: {}, shortcut: "Num-"),
            .init(title: "Select All", action: {}, shortcut: "Ctrl+A"),
            .init(title: "Unselect All", action: {}, shortcut: "Ctrl+U"),
            .init(title: "Invert Selection", action: {}, shortcut: nil),
        ]
    }

    private var commandMenuItems: [MenuItem] {
        [
            .init(title: "Open Command Prompt...", action: {}, shortcut: "Ctrl+P"),
            .init(title: "Open Desktop Folder", action: {}, shortcut: nil),
            .init(title: "CD Tree...", action: {}, shortcut: "Ctrl+D"),
            .init(title: "Branch View (With Subdirs)", action: {}, shortcut: "Ctrl+B"),
        ]
    }

    private var netMenuItems: [MenuItem] {
        [
            .init(title: "FTP Connect...", action: {}, shortcut: "Ctrl+N"),
            .init(title: "FTP Disconnect", action: {}, shortcut: nil),
            .init(title: "Network Neighborhood", action: {}, shortcut: nil),
        ]
    }

    private var showMenuItems: [MenuItem] {
        [
            .init(title: "Full View", action: {}, shortcut: nil),
            .init(title: "Brief View", action: {}, shortcut: nil),
            .init(title: "Hidden Files", action: {}, shortcut: "Ctrl+H"),
        ]
    }

    private var configMenuItems: [MenuItem] {
        [
            .init(title: "Options...", action: {}, shortcut: "Alt+O"),
            .init(title: "Customize Toolbar...", action: {}, shortcut: nil),
        ]
    }

    private var startMenuItems: [MenuItem] {
        [
            .init(title: "New Tab", action: {}, shortcut: "Ctrl+T"),
            .init(title: "Duplicate Tab", action: {}, shortcut: "Ctrl+D"),
            .init(title: "Close Tab", action: {}, shortcut: "Ctrl+W"),
        ]
    }

    private var helpMenuItems: [MenuItem] {
        [
            .init(title: "Contents", action: {}, shortcut: "F1"),
            .init(title: "Keyboard Shortcuts", action: {}, shortcut: nil),
            .init(title: "Check for Updates...", action: {}, shortcut: nil),
        ]
    }
}
