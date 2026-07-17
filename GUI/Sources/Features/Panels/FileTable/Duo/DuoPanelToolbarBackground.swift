//
// DuoPanelToolbarBackground.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 10.12.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import AppKit
import SwiftUI

// MARK: - Command Bar Appearance Defaults
enum CommandBarAppearanceDefaults {
    static let backgroundColor =
        Color(#colorLiteral(red: 0.84, green: 0.85, blue: 0.87, alpha: 1))
    static let moireIntensity = 0.28
}

// MARK: - Duo Panel Chrome Background
/// Shared top and bottom command-bar background.
struct DuoPanelToolbarBackground: View {
    let cornerRadius: CGFloat
    @AppStorage("color.commandBarBackground")
    private var hexBackground: String = ""
    @AppStorage("commandBar.moireIntensity")
    private var moireIntensity = CommandBarAppearanceDefaults.moireIntensity

    // MARK: - Body
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(toolbarFill)
            .overlay(moireOverlay)
            .overlay(toolbarHighlight)
            .overlay(toolbarBorder)
            .compositingGroup()
            .shadow(color: Color.black.opacity(0.10), radius: 2.5, y: 1)
    }

    private var toolbarFill: some ShapeStyle {
        LinearGradient(
            stops: [
                .init(color: backgroundColor.opacity(0.90), location: 0),
                .init(color: backgroundColor.opacity(0.96), location: 0.58),
                .init(color: backgroundColor, location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var backgroundColor: Color {
        Color(hex: hexBackground)
            ?? CommandBarAppearanceDefaults.backgroundColor
    }

    private var moireOverlay: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(moireIntensity * 0.34),
                        Color.clear,
                        Color.black.opacity(moireIntensity * 0.12),
                        Color.white.opacity(moireIntensity * 0.10)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    private var toolbarHighlight: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.34 + moireIntensity * 0.16),
                        Color.white.opacity(0.04),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .padding(1)
    }

    private var toolbarBorder: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(Color.black.opacity(0.18), lineWidth: 0.75)
    }
}
