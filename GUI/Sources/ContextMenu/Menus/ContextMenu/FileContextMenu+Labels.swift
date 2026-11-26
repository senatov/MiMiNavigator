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
            ContextMenuSymbol(name: action.systemImage)
        }
        .labelStyle(.titleAndIcon)
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
}
