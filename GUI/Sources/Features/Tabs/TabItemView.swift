// TabItemView.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Single bottom tab with glass-friendly compact styling.

import SwiftUI

// MARK: - Tab Item View
struct TabItemView: View {

    let tab: TabItem
    let isActive: Bool
    let isPanelFocused: Bool
    let isOnlyTab: Bool
    let tabCount: Int
    let onSelect: () -> Void
    let onClose: () -> Void
    let onCloseOthers: () -> Void
    let onCloseToRight: () -> Void
    let onDuplicate: () -> Void

    @State private var isHovered = false
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Layout constants
    private let tabHeight: CGFloat = 26
    private let minTabWidth: CGFloat = 80
    private let maxTabWidth: CGFloat = 180
    private let cornerRadius: CGFloat = 3

    // MARK: - Body

    var body: some View {
        tabContent
            .frame(height: tabHeight)
            .background(tabFill)
            .clipShape(tabShape)
            .overlay(tabBorder)
            .shadow(color: tabShadowColor, radius: isActive ? 1 : 0, x: 0, y: isActive ? -0.5 : 0)
            .onTapGesture { onSelect() }
            .onHover { isHovered = $0 }
            .contextMenu {
                TabContextMenu(
                    tab: tab,
                    isOnlyTab: isOnlyTab,
                    tabCount: tabCount,
                    onClose: onClose,
                    onCloseOthers: onCloseOthers,
                    onCloseToRight: onCloseToRight,
                    onDuplicate: onDuplicate
                )
            }
            .help(tab.displayName)
        .animation(.easeOut(duration: 0.15), value: isActive)
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }

    // MARK: - Tab Content

    private var tabContent: some View {
        HStack(spacing: 5) {
            // Favicon-style folder icon
            Image(systemName: tab.isArchive ? "doc.zipper" : "folder.fill")
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(
                    isActive
                        ? Color(nsColor: .systemGreen)
                        : inactiveForeground.opacity(0.72)
                )
                .frame(width: 14)

            Text(tab.truncatedDisplayName(maxLength: 16))
                .font(.system(size: 12, weight: isActive ? .bold : .medium, design: .default))
                .lineLimit(1)
                .foregroundStyle(isActive ? activeForeground : inactiveForeground)
                .shadow(color: activeTextHighlight, radius: 0, x: 0, y: isActive ? 1 : 0)
                .shadow(color: activeTextShade, radius: 0, x: 0, y: isActive ? -0.5 : 0)

            Spacer(minLength: 0)

            // Close button — always reserves space, visible on hover/active
            closeButton
        }
        .padding(.leading, 10)
        .padding(.trailing, isActive ? 7 : 5)
        .frame(minWidth: minTabWidth, maxWidth: maxTabWidth)
    }

    // MARK: - Close Button

    private var closeButton: some View {
        Button(action: {
            log.debug("[TabItemView] close '\(tab.displayName)'")
            onClose()
        }) {
            ZStack {
                Circle()
                    .fill(
                        isHovered
                            ? Color.secondary.opacity(0.2)
                            : Color.clear
                    )
                    .frame(width: 16, height: 16)

                Image(systemName: "xmark")
                    .font(.system(size: 7.5, weight: .bold))
                    .foregroundStyle(Color.secondary)
            }
            .frame(width: 16, height: 16)
        }
        .buttonStyle(.plain)
        .opacity((isActive || isHovered) && !isOnlyTab ? 1.0 : 0.0)
        .frame(width: 16)  // always occupies space to avoid layout shift
    }

    // MARK: - Tab Fill

    @ViewBuilder
    private var tabFill: some View {
        if isActive {
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor).opacity(colorScheme == .dark ? 0.74 : 1),
                    Color(nsColor: .controlBackgroundColor).opacity(colorScheme == .dark ? 0.52 : 0.96),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        } else if isHovered {
            Color(nsColor: .windowBackgroundColor).opacity(colorScheme == .dark ? 0.24 : 0.62)
        } else {
            Color(nsColor: .controlBackgroundColor).opacity(colorScheme == .dark ? 0.12 : 0.18)
        }
    }

    private var activeForeground: Color {
        isPanelFocused ? Color(nsColor: .systemGreen) : Color(nsColor: .darkGray)
    }

    private var inactiveForeground: Color {
        colorScheme == .dark
            ? Color(nsColor: .tertiaryLabelColor)
            : Color(nsColor: .darkGray)
    }

    private var activeTextHighlight: Color {
        isActive && isPanelFocused ? Color.white.opacity(colorScheme == .dark ? 0.1 : 0.72) : .clear
    }

    private var activeTextShade: Color {
        isActive && isPanelFocused ? Color.black.opacity(colorScheme == .dark ? 0.42 : 0.18) : .clear
    }

    private var tabShadowColor: Color {
        isPanelFocused ? Color.black.opacity(colorScheme == .dark ? 0.28 : 0.14) : .clear
    }

    private var tabBorder: some View {
        tabShape
            .stroke(
                isActive
                    ? Color(nsColor: .separatorColor).opacity(isPanelFocused ? 0.88 : 0.62)
                    : Color(nsColor: .separatorColor).opacity(0.26),
                lineWidth: 0.7
            )
    }

    private var tabShape: some Shape {
        UnevenRoundedRectangle(
            topLeadingRadius: cornerRadius,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 0,
            topTrailingRadius: cornerRadius,
            style: .continuous
        )
    }
}
