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

