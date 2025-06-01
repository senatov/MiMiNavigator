    //
    //  MenuItemView.swift
    //  MiMiNavigator
    //
    //  Created by Iakov Senatov on 18.02.25.
    //  Copyright © 2025 Senatov. All rights reserved.
    //
import SwiftUI

struct TopMenuItemView: View {
    let item: MenuItem
    @State private var isHovered = false
    @State private var isPressed = false
    @State private var showHelpText = false

    var body: some View {
        Button(action: {
            isPressed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                isPressed = false
            }
            item.action()
        }) {
            HStack {
                Text(item.title)
                Spacer()
                if let shortcut = item.shortcut {
                    Text(shortcut).foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                isPressed ? Color.blue.opacity(0.7) : isHovered ? Color.blue.opacity(0.3) : Color.clear
            )
            .cornerRadius(7)
        }
        .buttonStyle(TopMenuButtonStyle())
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if isHovered { showHelpText = true }
                }
            } else {
                showHelpText = false
            }
        }
        .popover(isPresented: $showHelpText, attachmentAnchor: .point(.trailing), arrowEdge: .leading) {
            HelpPopup(text: "This is a help text for \(item.title).")  // Всплывающее окно
        }
    }
}

    // MARK: - File Menu (Your bread-and-butter file ops)
var filesMenuCategory: MenuCategory {
    MenuCategory(title: "Files", items: filesMenuItems)
}

    // MARK: -
var filesMenuItems: [MenuItem] {
    [
        .init(title: "Rename/Move", action: { log.debug("Menu > Files > Rename/Move") }, shortcut: "F6"),
        .init(title: "Change Attributes...", action: { log.debug("Menu > Files > Change Attributes...") }, shortcut: "Ctrl+A"),
        .init(title: "Pack...", action: { log.debug("Menu > Files > Pack...") }, shortcut: "Alt+F5"),
        .init(title: "Unpack...", action: { log.debug("Menu > Files > Unpack...") }, shortcut: "Alt+F9"),
        .init(title: "Test Archive(s)", action: { log.debug("Menu > Files > Test Archive(s)") }, shortcut: nil),
        .init(title: "Compare By Content...", action: { log.debug("Menu > Files > Compare By Content...") }, shortcut: "Ctrl+C"),
        .init(title: "Synchronize Directories...", action: { log.debug("Menu > Files > Synchronize Directories...") }, shortcut: "Ctrl+S"),
        .init(title: "Quit", action: { log.debug("Menu > Files > Quit") }, shortcut: "Alt+F4"),
    ]
}

    // MARK: - Mark Menu (Select, unselect... the basics)
var markMenuCategory: MenuCategory {
    MenuCategory(title: "Mark", items: markMenuItems)
}

var markMenuItems: [MenuItem] {
    [
        .init(title: "Select Group...", action: { log.debug("Menu > Mark > Select Group...") }, shortcut: "Num+"),
        .init(title: "Unselect Group...", action: { log.debug("Menu > Mark > Unselect Group...") }, shortcut: "Num-"),
        .init(title: "Select All", action: { log.debug("Menu > Mark > Select All") }, shortcut: "Ctrl+A"),
        .init(title: "Unselect All", action: { log.debug("Menu > Mark > Unselect All") }, shortcut: "Ctrl+U"),
        .init(title: "Invert Selection", action: { log.debug("Menu > Mark > Invert Selection") }, shortcut: nil),
    ]
}

    // MARK: - Command Menu (CMD-style actions)
var commandMenuCategory: MenuCategory {
    MenuCategory(title: "Commands", items: commandMenuItems)
}

    // MARK: -
var commandMenuItems: [MenuItem] {
    [
        .init(title: "Open Command Prompt...", action: { log.debug("Menu > Commands > Open Command Prompt...") }, shortcut: "Ctrl+P"),
        .init(title: "Open Desktop Folder", action: { log.debug("Menu > Commands > Open Desktop Folder") }, shortcut: nil),
        .init(title: "CD Tree...", action: { log.debug("Menu > Commands > CD Tree...") }, shortcut: "Ctrl+D"),
        .init(title: "Branch View (With Subdirs)", action: { log.debug("Menu > Commands > Branch View (With Subdirs)") }, shortcut: "Ctrl+B"),
    ]
}

    // MARK: - Net Menu (The web stuff, FTP, etc.)
var netMenuCategory: MenuCategory {
    MenuCategory(title: "Net", items: netMenuItems)
}

    // MARK: -
var netMenuItems: [MenuItem] {
    [
        .init(title: "FTP Connect...", action: { log.debug("Menu > Net > FTP Connect...") }, shortcut: "Ctrl+N"),
        .init(title: "FTP Disconnect", action: { log.debug("Menu > Net > FTP Disconnect") }, shortcut: nil),
        .init(title: "Network Neighborhood", action: { log.debug("Menu > Net > Network Neighborhood") }, shortcut: nil),
    ]
}

    // MARK: - Show Menu (View-related options)
var showMenuCategory: MenuCategory {
    MenuCategory(title: "Show", items: showMenuItems)
}

var showMenuItems: [MenuItem] {
    [
        .init(title: "Full View", action: { log.debug("Menu > Show > Full View") }, shortcut: nil),
        .init(title: "Brief View", action: { log.debug("Menu > Show > Brief View") }, shortcut: nil),
        .init(title: "Hidden Files", action: { log.debug("Menu > Show > Hidden Files") }, shortcut: "Ctrl+H"),
    ]
}

    // MARK: - Configuration Menu (The power user’s playground)
var configMenuCategory: MenuCategory {
    MenuCategory(title: "Configuration", items: configMenuItems)
}

var configMenuItems: [MenuItem] {
    [
        .init(title: "Options...", action: { log.debug("Menu > Configuration > Options...") }, shortcut: "Alt+O"),
        .init(title: "Customize Toolbar...", action: { log.debug("Menu > Configuration > Customize Toolbar...") }, shortcut: nil),
    ]
}

    // MARK: - Start Menu (Tabs and layout management)
var startMenuCategory: MenuCategory {
    MenuCategory(title: "Start", items: startMenuItems)
}

var startMenuItems: [MenuItem] {
    [
        .init(title: "New Tab", action: { log.debug("Menu > Start > New Tab") }, shortcut: "Ctrl+T"),
        .init(title: "Duplicate Tab", action: { log.debug("Menu > Start > Duplicate Tab") }, shortcut: "Ctrl+D"),
        .init(title: "Close Tab", action: { log.debug("Menu > Start > Close Tab") }, shortcut: "Ctrl+W"),
    ]
}

    // MARK: - Help Menu (Docs, guides, updates)
var helpMenuCategory: MenuCategory {
    MenuCategory(title: "Help", items: helpMenuItems)
}

    // MARK: -
var helpMenuItems: [MenuItem] {
    [
        .init(title: "Index", action: { log.debug("Help > Index") }, shortcut: "F1"),
        .init(title: "Keyboard", action: { log.debug("Help > Keyboard") }, shortcut: nil),
        .init(title: "Registration Info", action: { log.debug("Help > Registration Info") }, shortcut: nil),
        .init(title: "Visit MimiNav Website", action: { log.debug("Help > Website") }, shortcut: nil),
        .init(title: "Check for Updates", action: { log.debug("Help > Check for Updates") }, shortcut: nil),
        .init(title: "About MimiNav…", action: { log.debug("Help > About MimiNav") }, shortcut: nil),
    ]
}

    // MARK: -
struct HelpPopup: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundColor(Color(#colorLiteral(red: 0.5787474513, green: 0.3215198815, blue: 0, alpha: 1)))  // Тёмно-синий цвет
            .padding(8)
            .background(Color.yellow.opacity(0.1))  // Бледно-жёлтый фон
            .cornerRadius(3)
            .frame(width: 200)  // Ограничение ширины
    }
}
