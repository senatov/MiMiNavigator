// DirectoryContextMenu.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 08.10.2025.
// Copyright © 2025-2026 Senatov. All rights reserved.
// Description: Context menu for directories - Finder-style layout

import SwiftUI

/// Context menu for directory items.
/// Matches Finder's context menu structure for folders.
struct DirectoryContextMenu: View {
    let file: CustomFile
    let panelSide: PanelSide
    let onAction: (DirectoryAction) -> Void
    
    init(file: CustomFile, panelSide: PanelSide, onAction: @escaping (DirectoryAction) -> Void) {
        self.file = file
        self.panelSide = panelSide
        self.onAction = onAction

    }
    
    var body: some View {
        Group {
            // ═══════════════════════════════════════════
            // SECTION 1: Navigation (directory-specific)
            // ═══════════════════════════════════════════
            menuButton(.open)
            menuButton(.openInNewTab)
            menuButton(.openInFinder)
            menuButton(.openInTerminal)
            menuButton(.viewLister)
            
            Divider()
            
            // ═══════════════════════════════════════════
            // SECTION 2: Edit actions (clipboard)
            // ═══════════════════════════════════════════
            menuButton(.cut)
            menuButton(.copy)
            menuButton(.paste)
            menuButton(.duplicate)
            
            Divider()
            
            // ═══════════════════════════════════════════
            // SECTION 3: Operations
            // ═══════════════════════════════════════════
            menuButton(.compress)
            menuButton(.share)
            
            Divider()
            
            // ═══════════════════════════════════════════
            // SECTION 4: Rename & Delete (danger zone)
            // ═══════════════════════════════════════════
            menuButton(.rename)
            menuButton(.delete)
            
            Divider()
            
            // ═══════════════════════════════════════════
            // SECTION 5: Info
            // ═══════════════════════════════════════════
            menuButton(.getInfo)

            Divider()

            // ═══════════════════════════════════════════
            // SECTION 6: Favorites
            // ═══════════════════════════════════════════
            menuButton(.addToFavorites)
        }
    }

    // MARK: - Menu Button Builder

    @ViewBuilder
    private func menuButton(_ action: DirectoryAction) -> some View {
        Button {
            log.debug("\(#function) action=\(action.rawValue) dir='\(file.nameStr)'")
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
    
    private func isActionDisabled(_ action: DirectoryAction) -> Bool {
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
        Text("Right-click for directory menu")
    }
    .frame(width: 300, height: 200)
    .contextMenu {
        DirectoryContextMenu(
            file: CustomFile(path: "/Users"),
            panelSide: .left,
            onAction: { action in
                log.debug("Action: \(action)")
            }
        )
    }
}
