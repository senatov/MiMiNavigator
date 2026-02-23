// FileContextMenu.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 08.10.2025.
// Refactored: 04.02.2026
// Copyright © 2025-2026 Senatov. All rights reserved.
// Description: Context menu for files - Finder-style layout with all standard actions

import SwiftUI

/// Context menu for file items (non-directory).
/// Matches Finder's context menu structure and functionality.
struct FileContextMenu: View {
    let file: CustomFile
    let panelSide: PanelSide
    let onAction: (FileAction) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    init(file: CustomFile, panelSide: PanelSide, onAction: @escaping (FileAction) -> Void) {
        self.file = file
        self.panelSide = panelSide
        self.onAction = onAction

    }
    
    var body: some View {
        Group {
            // ═══════════════════════════════════════════
            // SECTION 1: Open actions
            // ═══════════════════════════════════════════
            menuButton(.open)
            OpenWithSubmenu(file: file)
            menuButton(.openInNewTab)
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
            // SECTION 4: Navigation
            // ═══════════════════════════════════════════
            menuButton(.revealInFinder)
            
            Divider()
            
            // ═══════════════════════════════════════════
            // SECTION 5: Rename & Delete (danger zone)
            // ═══════════════════════════════════════════
            menuButton(.rename)
            menuButton(.delete)
            
            Divider()
            
            // ═══════════════════════════════════════════
            // SECTION 6: Info
            // ═══════════════════════════════════════════
            menuButton(.getInfo)

            Divider()

            // ═══════════════════════════════════════════
            // SECTION 7: Favorites
            // ═══════════════════════════════════════════
            menuButton(.addToFavorites)
        }
    }

    // MARK: - Menu Button Builder

    @ViewBuilder
    private func menuButton(_ action: FileAction) -> some View {
        Button {
            log.debug("\(#function) action=\(action.rawValue) file='\(file.nameStr)'")
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
    
    private func isActionDisabled(_ action: FileAction) -> Bool {
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
        Text("Right-click for file menu")
    }
    .frame(width: 300, height: 200)
    .contextMenu {
        FileContextMenu(
            file: CustomFile(path: "/test/document.txt"),
            panelSide: .left,
            onAction: { action in
                log.debug("Action: \(action)")
            }
        )
    }
}
