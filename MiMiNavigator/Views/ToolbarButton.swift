//
//  ToolbarButton.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 21.02.25.
//  Copyright © 2025 Senatov. All rights reserved.
//

import SwiftUI
import SwiftyBeaver

struct ToolbarButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    @State private var isHovered = false
    @State private var isPressed = false
    @State private var showHelpText = false

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation { isPressed = false }
            }
            action()
        }) {
            Label(title, systemImage: systemImage)
                .labelStyle(.titleAndIcon)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isHovered ? Color.blue.opacity(0.3) : Color.clear) // Видимый фон при наведении
                        .animation(.easeInOut(duration: 0.3), value: isHovered)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isHovered ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 1) // Рамка при наведении
                        .animation(.easeInOut(duration: 0.3), value: isHovered)
                )
                .scaleEffect(isPressed ? 0.95 : 1.0)
        }
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
            HelpPopup(text: "This is a help text for \(title).")  
        }
    }
}
