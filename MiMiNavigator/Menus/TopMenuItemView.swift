//
//  MenuItemView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 18.02.25.
//  Copyright © 2025 Senatov. All rights reserved.
//

import SwiftUI

// MARK: -
struct MenuItemContent: View {
    let title: String
    let shortcut: String?

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            if let shortcut = shortcut {
                Text(shortcut)
                    .foregroundColor(.gray)
                    .font(.caption)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }
}
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
