    //
    //  MenuItemView.swift
    //  MiMiNavigator
    //
    //  Created by Iakov Senatov on 18.02.25.
    //  Copyright © 2025 Senatov. All rights reserved.
    //

import SwiftUI

    // MARK: -
struct TopMenuItemView: View {
    let item: MenuItem
    @State private var isHovered = false
    @State private var isPressed = false
    @State private var showHelpText = false
    @State private var hoverTask: Task<Void, Never>? = nil
    
    var body: some View {
        Button(action: {
            isPressed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                isPressed = false
            }
            item.action()
        }) {
            MenuItemContent(title: item.title, shortcut: item.shortcut)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isPressed ? Color.blue.opacity(0.7) : (isHovered ? Color.blue.opacity(0.3) : Color.clear))
                )
        }
        .buttonStyle(TopMenuButtonStyle())
        .animation(nil, value: isHovered)
        .animation(nil, value: isPressed)
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onHover { hovering in
            isHovered = hovering
            hoverTask?.cancel()
            if hovering {
                hoverTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s debounce
                    if !Task.isCancelled && isHovered { showHelpText = true }
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
