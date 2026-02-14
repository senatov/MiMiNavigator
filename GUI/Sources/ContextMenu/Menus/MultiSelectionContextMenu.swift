// MultiSelectionContextMenu.swift
// MiMiNavigator
//
// Created by Claude on 14.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Context menu for multiple selected files/directories

import SwiftUI

// MARK: - Multi Selection Context Menu
/// Context menu shown when multiple files are marked (selected).
/// Shows only actions that make sense for batch operations.
struct MultiSelectionContextMenu: View {
    let markedCount: Int
    let panelSide: PanelSide
    let onAction: (MultiSelectionAction) -> Void

    var body: some View {
        Group {
            // Header: show count of selected items
            Text("\(markedCount) items selected")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            // ═══════════════════════════════════════════
            // SECTION 1: Clipboard operations
            // ═══════════════════════════════════════════
            menuButton(.cut)
            menuButton(.copy)
            menuButton(.paste)

            Divider()

            // ═══════════════════════════════════════════
            // SECTION 2: Batch operations
            // ═══════════════════════════════════════════
            menuButton(.compress)
            menuButton(.share)

            Divider()

            // ═══════════════════════════════════════════
            // SECTION 3: Navigation
            // ═══════════════════════════════════════════
            menuButton(.revealInFinder)

            Divider()

            // ═══════════════════════════════════════════
            // SECTION 4: Danger zone
            // ═══════════════════════════════════════════
            menuButton(.delete)
        }
    }

    // MARK: - Menu Button Builder

    @ViewBuilder
    private func menuButton(_ action: MultiSelectionAction) -> some View {
        Button {
            log.debug("[MultiSelectionContextMenu] action=\(action.rawValue) count=\(markedCount)")
            onAction(action)
        } label: {
            Label {
                HStack {
                    Text(action.title)
                    Spacer()
                    if let shortcut = action.shortcutHint {
                        Text(shortcut)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } icon: {
                Image(systemName: action.systemImage)
            }
        }
        .disabled(isActionDisabled(action))
    }

    // MARK: - Action State

    private func isActionDisabled(_ action: MultiSelectionAction) -> Bool {
        switch action {
        case .paste:
            return !ClipboardManager.shared.hasContent
        default:
            return false
        }
    }
}

// MARK: - Preview
#Preview {
    VStack {
        Text("Right-click for multi-selection menu")
    }
    .frame(width: 300, height: 200)
    .contextMenu {
        MultiSelectionContextMenu(
            markedCount: 5,
            panelSide: .left,
            onAction: { action in
                print("Multi action: \(action)")
            }
        )
    }
}
