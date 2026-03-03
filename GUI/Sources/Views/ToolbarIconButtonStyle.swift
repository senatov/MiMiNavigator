//
// ToolbarIconButtonStyle.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 03.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: macOS HIG 26 compliant button style for toolbar icons

import SwiftUI

/// HIG 26 compliant toolbar icon button style.
/// - Normal: secondary color (grey)
/// - Hover: accent color with subtle background
/// - Pressed: slightly darker accent
struct ToolbarIconButtonStyle: ButtonStyle {
    @State private var isHovering = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foregroundColor(isPressed: configuration.isPressed))
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(backgroundColor(isPressed: configuration.isPressed))
            )
            .contentShape(Rectangle())
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovering = hovering
                }
            }
    }
    
    private func foregroundColor(isPressed: Bool) -> Color {
        if isPressed {
            return .accentColor.opacity(0.8)
        } else if isHovering {
            return .accentColor
        } else {
            return .secondary
        }
    }
    
    private func backgroundColor(isPressed: Bool) -> Color {
        if isPressed {
            return Color.accentColor.opacity(0.15)
        } else if isHovering {
            return Color.secondary.opacity(0.1)
        } else {
            return .clear
        }
    }
}
