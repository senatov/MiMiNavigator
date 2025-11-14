//
//  TopMenuBarStyle.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 09.03.25.
//  Copyright © 2025 Senatov. All rights reserved.
//

import SwiftUI

// MARK: - TopMenuButtonStyle
// Visual style for top-row text buttons to match macOS/Figma menu look.
// - Subtle hover/press background (no opaque fills)
// - Small typography (13pt), compact paddings
// - Rounded hit area, thin separator stroke only on hover/press
// - Works in light/dark mode; no ignoresSafeArea usage
struct TopMenuButtonStyle: ButtonStyle {
    public init() {}

    // MARK: -
    public func makeBody(configuration: Configuration) -> some View {
        _TopMenuButton(configuration: configuration)
    }

    // MARK: - Internal view managing hover state and visuals
    private struct _TopMenuButton: View {
        let configuration: Configuration
        // Layout constants tuned for macOS menu-like row
        private let cornerRadius: CGFloat = 8
        private let horizontalPadding: CGFloat = 10
        private let verticalPadding: CGFloat = 4
        private let minHeight: CGFloat = 26
        private let fontSize: CGFloat = 13
        @Environment(\.isEnabled) private var isEnabled
        @State private var isHovered: Bool = false

        // MARK: - Background for hover/press, transparent by default
        private var background: some View {
            Group {
                if configuration.isPressed {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.tertiary)  // slightly stronger for pressed
                } else if isHovered {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.quaternary)  // subtle hover
                } else {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.clear)
                }
            }
        }

        // MARK: - Hairline stroke only when interactive (hover/press)
        private var stroke: some View {
            Group {
                if configuration.isPressed || isHovered {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(.separator, lineWidth: 0.5)
                } else {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(.clear, lineWidth: 0)
                }
            }
        }

        // MARK: -
        var body: some View {
            configuration.label
                .font(.system(size: fontSize, weight: .regular))
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, verticalPadding)
                .frame(minHeight: minHeight, alignment: .center)
                .foregroundStyle(isEnabled ? .primary : .secondary)
                .contentShape(RoundedRectangle(cornerRadius: cornerRadius))  // precise hit area
                .background(background)
                .overlay(stroke)
                .cornerRadius(cornerRadius)
                .onHover { isHovered = $0 }
                .animation(.easeInOut(duration: 0.12), value: isHovered)
                .animation(.easeInOut(duration: 0.08), value: configuration.isPressed)
                .opacity(isEnabled ? 1.0 : 0.5)
                .focusable(false)  // avoid focus ring around text-like buttons
                .textSelection(.disabled)  // no text selection in menu row
        }
    }
}
