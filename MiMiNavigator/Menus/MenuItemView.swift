//
//  MenuItemView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 18.02.25.
//  Copyright © 2025 Senatov. All rights reserved.
//
import SwiftUI

struct MenuItemView: View {
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
            .padding(.vertical, 4)
            .background(
                isPressed ? Color.blue.opacity(0.7) : isHovered ? Color.blue.opacity(0.3) : Color.clear
            )
            .cornerRadius(5)
        }
        .buttonStyle(PlainButtonStyle())  // Убираем стандартные кнопочные эффекты
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
var markMenuCategory: MenuCategory {
    MenuCategory(title: "Mark", items: markMenuItems)
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
var commandMenuCategory: MenuCategory {
    MenuCategory(title: "Commands", items: commandMenuItems)
}

var commandMenuItems: [MenuItem] {
    [
        .init(title: "Open Command Prompt...", action: {}, shortcut: "Ctrl+P"),
        .init(title: "Open Desktop Folder", action: {}, shortcut: nil),
        .init(title: "CD Tree...", action: {}, shortcut: "Ctrl+D"),
        .init(title: "Branch View (With Subdirs)", action: {}, shortcut: "Ctrl+B"),
    ]
}

// MARK: - Net Menu (The web stuff, FTP, etc.)
var netMenuCategory: MenuCategory {
    MenuCategory(title: "Net", items: netMenuItems)
}

var netMenuItems: [MenuItem] {
    [
        .init(title: "FTP Connect...", action: {}, shortcut: "Ctrl+N"),
        .init(title: "FTP Disconnect", action: {}, shortcut: nil),
        .init(title: "Network Neighborhood", action: {}, shortcut: nil),
    ]
}

// MARK: - Show Menu (View-related options)
var showMenuCategory: MenuCategory {
    MenuCategory(title: "Show", items: showMenuItems)
}

var showMenuItems: [MenuItem] {
    [
        .init(title: "Full View", action: {}, shortcut: nil),
        .init(title: "Brief View", action: {}, shortcut: nil),
        .init(title: "Hidden Files", action: {}, shortcut: "Ctrl+H"),
    ]
}

// MARK: - Configuration Menu (The power user’s playground)
var configMenuCategory: MenuCategory {
    MenuCategory(title: "Configuration", items: configMenuItems)
}

var configMenuItems: [MenuItem] {
    [
        .init(title: "Options...", action: {}, shortcut: "Alt+O"),
        .init(title: "Customize Toolbar...", action: {}, shortcut: nil),
    ]
}

// MARK: - Start Menu (Tabs and layout management)
var startMenuCategory: MenuCategory {
    MenuCategory(title: "Start", items: startMenuItems)
}

var startMenuItems: [MenuItem] {
    [
        .init(title: "New Tab", action: {}, shortcut: "Ctrl+T"),
        .init(title: "Duplicate Tab", action: {}, shortcut: "Ctrl+D"),
        .init(title: "Close Tab", action: {}, shortcut: "Ctrl+W"),
    ]
}

// MARK: - Help Menu (Docs, guides, updates)
var helpMenuCategory: MenuCategory {
    MenuCategory(title: "Help", items: helpMenuItems)
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
            .font(.system(size: 12))  // Мелкий шрифт
            .foregroundColor(.black)
            .padding(8)
            .background(Color.yellow.opacity(0.9))  // Бледно-жёлтый фон
            .cornerRadius(5)
            .frame(width: 200)  // Ограничение ширины
    }
}


struct BlurView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .menu // Используем стандартное размытие меню macOS
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
