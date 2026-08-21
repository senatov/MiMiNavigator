// TopMenuButtonStyle.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 09.03.25.
// Copyright © 2025 Senatov. All rights reserved.
// Description: Compact dimensional style for top-row command buttons.

import SwiftUI

// MARK: - TopMenuButtonStyle
/// Visual style for top-row text buttons to match macOS/Figma menu look.
/// - Subtle hover/press background (no opaque fills)
/// - Small typography (13pt), compact paddings
/// - Rounded hit area, thin separator stroke only on hover/press
/// - Works in light/dark mode; no ignoresSafeArea usage
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
        // Layout constants tuned for macOS menu-like row
        private let cornerRadius: CGFloat = 6
        private let horizontalPadding: CGFloat = 10
        private let verticalPadding: CGFloat = 4
        private let minHeight: CGFloat = 26
        private let fontSize: CGFloat = 14
        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.colorScheme) private var colorScheme
        @State private var isHovered: Bool = false

        // MARK: - Background
        private var background: some View {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: configuration.isPressed
                            ? [Color.black.opacity(0.09), Color.white.opacity(0.10)]
                            : [
                                Color.white.opacity(colorScheme == .dark ? (isHovered || isSelected ? 0.16 : 0.08) : (isHovered || isSelected ? 0.62 : 0.30)),
                                (isSelected ? Color.accentColor : Color.primary).opacity(isHovered || isSelected ? 0.11 : 0.045)
                            ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }

        // MARK: - Hairline stroke only when interactive (hover/press)
        private var stroke: some View {
            Group {
                if configuration.isPressed || isHovered || isSelected {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(
                            isSelected ? Color.accentColor.opacity(0.46) : Color.black.opacity(0.20),
                            lineWidth: 0.75
                        )
                } else {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(Color.black.opacity(0.10), lineWidth: 0.5)
                }
            }
        }

        // MARK: -
        var body: some View {
            configuration.label
                .font(.system(size: fontSize, weight: .medium))
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, verticalPadding)
                .frame(minHeight: minHeight, alignment: .center)
                .foregroundStyle(isEnabled ? .primary : .secondary)
                .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
                .background(background)
                .overlay(stroke)
                .overlay(alignment: .top) {
                    Capsule()
                        .fill(Color.white.opacity(configuration.isPressed ? 0.08 : colorScheme == .dark ? 0.14 : 0.48))
                        .frame(height: 0.75)
                        .padding(.horizontal, 5)
                        .padding(.top, 1)
                }
                .shadow(color: Color.black.opacity(configuration.isPressed ? 0.04 : 0.10), radius: 1, y: configuration.isPressed ? 0 : 1)
                .offset(y: configuration.isPressed ? 0.5 : 0)
                .clipShape(.rect(cornerRadius: cornerRadius))
                .onHover { isHovered = $0 }
                .animation(.easeInOut(duration: 0.12), value: isHovered)
                .animation(.easeInOut(duration: 0.08), value: configuration.isPressed)
                .opacity(isEnabled ? 1.0 : 0.5)
                .focusEffectDisabled()
                .textSelection(.disabled)
        }
    }
}
