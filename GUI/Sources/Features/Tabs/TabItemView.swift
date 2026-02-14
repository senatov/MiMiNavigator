// TabItemView.swift
// MiMiNavigator
//
// Created by Claude on 14.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Single tab button in the tab bar — shows truncated name, close button, active state

import SwiftUI

// MARK: - Tab Item View
/// Renders a single tab with name, close button, and active/inactive styling.
/// Matches macOS tab bar aesthetics (Safari/Finder style).
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

    // MARK: - State

    @State private var isHovered = false

    // MARK: - Body

    var body: some View {
        HStack(spacing: 4) {
            // Tab icon
            tabIcon

            // Tab name
            Text(tab.truncatedDisplayName(maxLength: 18))
                .font(.system(size: 11, weight: isActive ? .medium : .regular))
                .lineLimit(1)
                .foregroundStyle(isActive ? .primary : .secondary)

            // Close button (hidden for only tab, shown on hover or active)
            if !isOnlyTab {
                closeButton
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(tabBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusSmall, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.radiusSmall, style: .continuous)
                .stroke(
                    isActive
                        ? Color.accentColor.opacity(0.4)
                        : DesignTokens.separator.opacity(isHovered ? 0.4 : 0.2),
                    lineWidth: 0.5
                )
        )
        .onTapGesture {
            log.debug("[TabItemView] tapped tab '\(tab.displayName)' id=\(tab.id)")
            onSelect()
        }
        .onHover { hovering in
            isHovered = hovering
        }
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
        .accessibilityLabel("Tab: \(tab.displayName)")
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    // MARK: - Tab Icon

    private var tabIcon: some View {
        Image(systemName: tab.isArchive ? "doc.zipper" : "folder.fill")
            .font(.system(size: 10))
            .foregroundStyle(isActive ? .orange : .secondary)
    }

    // MARK: - Close Button

    private var closeButton: some View {
        Button(action: {
            log.debug("[TabItemView] close tab '\(tab.displayName)' id=\(tab.id)")
            onClose()
        }) {
            Image(systemName: "xmark")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: 14, height: 14)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(isActive || isHovered ? 1.0 : 0.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .accessibilityLabel("Close tab \(tab.displayName)")
    }

    // MARK: - Tab Background

    private var tabBackground: some View {
        Group {
            if isActive {
                DesignTokens.card.opacity(0.9)
            } else if isHovered {
                DesignTokens.card.opacity(0.5)
            } else {
                Color.clear
            }
        }
    }
}
