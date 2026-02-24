//
// MenuItemView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 18.02.25.
//  Copyright © 2025 Senatov. All rights reserved.
// Description: Menu item view — reads live shortcuts from HotKeyStore (@Observable)
//

import SwiftUI

// MARK: -
struct TopMenuItemView: View {
    let item: MenuItem
    @State private var isHovered = false
    @State private var isPressed = false
    @State private var showHelpText = false
    @State private var hoverTask: Task<Void, Never>? = nil

    // MARK: - Live shortcut from @Observable HotKeyStore
    /// Reading HotKeyStore.shared inside body makes SwiftUI track changes automatically.
    private var liveShortcut: String? {
        if let hkAction = item.hotKeyAction {
            let binding = HotKeyStore.shared.binding(for: hkAction)
            guard binding.keyCode != 0 else { return nil }
            let display = binding.displayString
            return display.isEmpty ? nil : display
        }
        return item.staticShortcut
    }

    var body: some View {
        Button(action: {
            isPressed = true
            Task {
                try? await Task.sleep(for: .milliseconds(200))
                isPressed = false
            }
            item.action()
        }) {
            MenuItemContent(title: item.title, shortcut: liveShortcut)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isPressed ? Color.blue.opacity(0.7) : (isHovered ? Color.blue.opacity(0.3) : Color.clear))
                )
        }
        .buttonStyle(TopMenuButtonStyle())
        .animation(nil, value: isHovered)
        .animation(nil, value: isPressed)
        .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .onHover { hovering in
            isHovered = hovering
            hoverTask?.cancel()
            if hovering {
                hoverTask = Task {
                    try? await Task.sleep(for: .milliseconds(500))
                    if !Task.isCancelled {
                        showHelpText = true
                    }
                }
            } else {
                showHelpText = false
            }
        }
        .popover(isPresented: $showHelpText) {
            HelpPopup(text: "This is a help text for \(item.title).")
        }
    }
}
