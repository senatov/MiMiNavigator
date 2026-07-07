// ThemedButtonStyle.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 26.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Button style with configurable border, corner radius, and shadow.
//   Reads values live from ColorThemeStore — updates instantly from Settings.

import SwiftUI

// MARK: - Themed Button Style
/// Applies thin border + shadow from ColorThemeStore to any Button.
/// Usage: .buttonStyle(ThemedButtonStyle())
struct ThemedButtonStyle: ButtonStyle {
    var tint: Color? = nil
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        DownToolbarGlassButtonStyle(
            isHovered: isHovered,
            tint: tint,
            horizontalPadding: 12,
            verticalPadding: 6
        )
        .makeBody(configuration: configuration)
        .onHover { hovering in
            withAnimation(.spring(response: 0.22, dampingFraction: 0.72)) {
                isHovered = hovering
            }
        }
    }
}
