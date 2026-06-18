// MultiSelectionContextMenu.swift
// MiMiNavigator
//
// Created by Claude on 14.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Context menu for multiple selected files/directories

import SwiftUI
import FileModelKit

// MARK: - Multi Selection Context Menu
/// Context menu shown when multiple files are marked (selected).
/// Shows only actions that make sense for batch operations.
struct MultiSelectionContextMenu: View {
    let markedCount: Int
    let panelSide: FavPanelSide
    let isOptionHeld: Bool
    let onAction: (MultiSelectionAction) -> Void

    @ViewBuilder
    private var moreSelectionOperationsMenu: some View {
        Menu {
            menuButton(.cut)
            menuButton(.copy)
            menuButton(.paste)
            Divider()
            menuButton(.delete)
        } label: {
            Label {
                Text("􀉒 File Operations")
            } icon: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    var body: some View {
        Text("\(markedCount) items selected")
            .font(.caption)
            .foregroundStyle(.secondary)
        Divider()
        moreSelectionOperationsMenu
        Divider()
        menuButton(.copyAsPathname)
        Divider()
        menuButton(.compress)
        menuButton(.share)
        Divider()
        menuButton(.revealInFinder)
        menuButton(.console)
        Divider()
        menuButton(.mirrorPanel)
        menuButton(.addToFavorites)
        Divider()
        menuButton(.getInfo)
    }

    // MARK: - Menu Button Builder

    @ViewBuilder
    private func menuButton(_ action: MultiSelectionAction) -> some View {
        Button {
            log.debug("[MultiSelectionContextMenu] tap action=\(action.rawValue) count=\(markedCount) optionHeld=\(isOptionHeld)")
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
                    .symbolRenderingMode(iconRenderingMode(for: action))
                    .foregroundStyle(iconColor(for: action))
                    .font(iconFont(for: action))
            }
        }
        .disabled(isActionDisabled(action))
    }

    private func iconRenderingMode(for action: MultiSelectionAction) -> SymbolRenderingMode {
        switch action {
        case .console:
            .palette
        case .copyAsPathname:
            .hierarchical
        default:
            .monochrome
        }
    }

    private func iconColor(for action: MultiSelectionAction) -> Color {
        switch action {
        case .console:
            .green
        case .copyAsPathname:
            .blue
        default:
            .primary
        }
    }

    private func iconFont(for action: MultiSelectionAction) -> Font {
        switch action {
        case .console:
            .system(size: 17, weight: .semibold)
        default:
            .body
        }
    }

    // MARK: - Action State

    private func isActionDisabled(_ action: MultiSelectionAction) -> Bool {
        switch action {
        case .paste:
            let disabled = !ClipboardManager.shared.hasContent
            log.debug("[MultiSelectionContextMenu] paste availability count=\(markedCount) hasContent=\(!disabled)")
            return disabled
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
            isOptionHeld: false,
            onAction: { action in
                log.debug("Multi action: \(action)")
            }
        )
    }
}
