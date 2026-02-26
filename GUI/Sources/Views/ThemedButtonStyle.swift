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

    @State private var store = ColorThemeStore.shared

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: store.buttonCornerRadius, style: .continuous)
                    .fill(configuration.isPressed
                          ? Color(nsColor: .controlBackgroundColor).opacity(0.7)
                          : Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: store.buttonCornerRadius, style: .continuous)
                    .stroke(buttonBorderColor, lineWidth: store.buttonBorderWidth)
            )
            .shadow(
                color: buttonShadowColor,
                radius: store.buttonShadowRadius,
                x: 0,
                y: store.buttonShadowY
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }

    private var buttonBorderColor: Color {
        if let c = Color(hex: store.hexButtonBorder), !store.hexButtonBorder.isEmpty {
            return c
        }
        return Color.gray.opacity(0.35)
    }

    private var buttonShadowColor: Color {
        if let c = Color(hex: store.hexButtonShadow), !store.hexButtonShadow.isEmpty {
            return c
        }
        return Color.black.opacity(0.1)
    }
}
