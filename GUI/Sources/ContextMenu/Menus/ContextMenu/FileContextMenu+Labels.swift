// FileContextMenu+Labels.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 28.05.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Labels and icon styling for FileContextMenu.

import SwiftUI

// MARK: - Labels

extension FileContextMenu {
    // MARK: - Menu Label
    @ViewBuilder
    func menuLabel(for action: FileAction) -> some View {
        Label {
            HStack {
                Text(action.title)
                Spacer()
                shortcutView(for: action)
            }
        } icon: {
            menuIcon(for: action)
        }
    }

    // MARK: - Shortcut View
    @ViewBuilder
    func shortcutView(for action: FileAction) -> some View {
        if let shortcut = shortcutHint(for: action) {
            Text(shortcut)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Shortcut Hint
    func shortcutHint(for action: FileAction) -> String? {
        if action == .rename {
            return HotKeyStore.shared.shortcutString(for: .renameFile)
        }
        return action.shortcutHint
    }

    // MARK: - Menu Icon
    @ViewBuilder
    func menuIcon(for action: FileAction) -> some View {
        Image(systemName: action.systemImage)
            .symbolRenderingMode(iconRenderingMode(for: action))
            .foregroundStyle(iconColor(for: action))
    }

    // MARK: - Icon Rendering Mode
    func iconRenderingMode(for action: FileAction) -> SymbolRenderingMode {
        switch action {
        case .copyAsPathname:
            .hierarchical
        default:
            .monochrome
        }
    }

    // MARK: - Icon Color
    func iconColor(for action: FileAction) -> Color {
        switch action {
        case .copyAsPathname:
            .blue
        default:
            .primary
        }
    }
}
