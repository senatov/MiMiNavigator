// TabItemView.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 14.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Single tab — MS Edge style: rounded top, active tab elevated, crisp close button

import SwiftUI

// MARK: - Tab Item View
struct TabItemView: View {

    let tab: TabItem
    let isActive: Bool
    let isOnlyTab: Bool
    let tabCount: Int
    let onSelect: () -> Void
    let onClose: () -> Void
    let onCloseOthers: () -> Void
    let onCloseToRight: () -> Void
    let onDuplicate: () -> Void

    @State private var isHovered = false
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Layout constants (Edge-style)
    private let tabHeight: CGFloat = 28
    private let minTabWidth: CGFloat = 60
    private let maxTabWidth: CGFloat = 180
    private let cornerRadius: CGFloat = 8

    // MARK: - Body

    var body: some View {
        HStack(spacing: 0) {
            // Left shoulder curve (active tab only)
            if isActive {
                shoulderCurve(mirrored: false)
            }

            tabContent
                .frame(height: tabHeight)
                .background(tabFill)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: cornerRadius,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: cornerRadius,
                        style: .continuous
                    )
                )
                .shadow(
                    color: isActive ? Color.black.opacity(colorScheme == .dark ? 0.4 : 0.12) : .clear,
                    radius: isActive ? 3 : 0,
                    x: 0,
                    y: isActive ? -1 : 0
                )
                .offset(y: isActive ? -1 : 2)  // active tab "floats" above the bar
                .zIndex(isActive ? 10 : 0)
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
                .help(tab.path)

            // Right shoulder curve (active tab only)
            if isActive {
                shoulderCurve(mirrored: true)
            }
        }
        .animation(.easeOut(duration: 0.15), value: isActive)
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }

    // MARK: - Tab Content

    private var tabContent: some View {
        HStack(spacing: 5) {
            // Favicon-style folder icon
            Image(systemName: tab.isArchive ? "doc.zipper" : "folder.fill")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(
                    isActive
                        ? Color.accentColor
                        : Color.secondary.opacity(0.7)
                )
                .frame(width: 14)

            // Tab name
            Text(tab.truncatedDisplayName(maxLength: 16))
                .font(.system(size: 11, weight: isActive ? .medium : .regular))
                .lineLimit(1)
                .foregroundStyle(isActive ? Color.primary : Color.secondary)

            Spacer(minLength: 0)

            // Close button — always reserves space, visible on hover/active
            closeButton
        }
        .padding(.leading, 10)
        .padding(.trailing, 6)
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
            // Active: solid window background — same as content below
            Color(nsColor: .windowBackgroundColor)
        } else if isHovered {
            Color(nsColor: .controlBackgroundColor).opacity(0.7)
        } else {
            Color(nsColor: .controlBackgroundColor).opacity(0.35)
        }
    }

    // MARK: - Shoulder curves (Edge-style concave corners)

    /// The little curved "ears" where the active tab meets the bar — Edge trademark
    @ViewBuilder
    private func shoulderCurve(mirrored: Bool) -> some View {
        Canvas { ctx, size in
            // Draw a filled quarter-circle that cuts into the bar corner
            let r: CGFloat = 6
            var path = Path()
            if mirrored {
                path.move(to: CGPoint(x: 0, y: size.height))
                path.addQuadCurve(
                    to: CGPoint(x: r, y: size.height - r),
                    control: CGPoint(x: r, y: size.height)
                )
                path.addLine(to: CGPoint(x: r, y: 0))
                path.addLine(to: CGPoint(x: 0, y: 0))
            } else {
                path.move(to: CGPoint(x: size.width, y: size.height))
                path.addQuadCurve(
                    to: CGPoint(x: size.width - r, y: size.height - r),
                    control: CGPoint(x: size.width - r, y: size.height)
                )
                path.addLine(to: CGPoint(x: size.width - r, y: 0))
                path.addLine(to: CGPoint(x: size.width, y: 0))
            }
            path.closeSubpath()
            ctx.fill(path, with: .color(Color(nsColor: .windowBackgroundColor)))
        }
        .frame(width: 10, height: tabHeight)
        .offset(y: -1)
    }
}
