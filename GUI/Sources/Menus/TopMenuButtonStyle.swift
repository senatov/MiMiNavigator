// TopMenuButtonStyle.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 09.03.25.
// Copyright © 2025 Senatov. All rights reserved.
// Description: Flat menu-header style matching the bottom command bar typography.

import SwiftUI

// MARK: - TopMenuButtonStyle
struct TopMenuButtonStyle: ButtonStyle {
    let isSelected: Bool

    init(isSelected: Bool = false) {
        self.isSelected = isSelected
    }

    // MARK: -
    public func makeBody(configuration: Configuration) -> some View {
        _TopMenuButton(configuration: configuration, isSelected: isSelected)
    }

    // MARK: - Internal view managing hover state and visuals
    private struct _TopMenuButton: View {
        let configuration: Configuration
        let isSelected: Bool
        private let cornerRadius: CGFloat = 5
        private let horizontalPadding: CGFloat = 8
        private let verticalPadding: CGFloat = 5
        private let minHeight: CGFloat = 25
        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.colorScheme) private var colorScheme
        @State private var isHovered: Bool = false

        // MARK: - Body
        var body: some View {
            configuration.label
                .font(.system(size: 14, weight: .light))
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, verticalPadding)
                .frame(minHeight: minHeight, alignment: .center)
                .foregroundStyle(isEnabled ? Color.primary.opacity(0.92) : Color.secondary)
                .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
                .background {
                    if configuration.isPressed || isHovered || isSelected {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(menuHighlight)
                    }
                }
                .overlay(alignment: .bottom) {
                    if isSelected {
                        Capsule()
                            .fill(Color.accentColor.opacity(0.78))
                            .frame(height: 1.5)
                            .padding(.horizontal, 7)
                    }
                }
                .onHover { isHovered = $0 }
                .animation(.easeInOut(duration: 0.12), value: isHovered)
                .animation(.easeInOut(duration: 0.08), value: configuration.isPressed)
                .opacity(isEnabled ? 1.0 : 0.5)
                .focusEffectDisabled()
                .textSelection(.disabled)
        }

        private var menuHighlight: Color {
            if isSelected { return Color.accentColor.opacity(colorScheme == .dark ? 0.20 : 0.12) }
            if configuration.isPressed { return Color.primary.opacity(0.13) }
            return Color.primary.opacity(colorScheme == .dark ? 0.15 : 0.11)
        }
    }
}
