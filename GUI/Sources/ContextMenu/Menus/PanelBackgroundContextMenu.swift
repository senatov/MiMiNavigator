// PanelBackgroundContextMenu.swift
// MiMiNavigator
//
// Created by Claude AI on 04.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Context menu for empty panel area (Finder-style)

import SwiftUI

/// Context menu shown when right-clicking on empty area of file panel
struct PanelBackgroundContextMenu: View {
    let panelSide: PanelSide
    let currentPath: URL
    let onAction: (PanelBackgroundAction) -> Void
    
    init(panelSide: PanelSide, currentPath: URL, onAction: @escaping (PanelBackgroundAction) -> Void) {
        self.panelSide = panelSide
        self.currentPath = currentPath
        self.onAction = onAction
        log.debug("\(#function) → panel=\(panelSide) path='\(currentPath.path)'")
    }
    
    var body: some View {
        Group {
            // ═══════════════════════════════════════════
            // SECTION 1: Navigation
            // ═══════════════════════════════════════════
            menuButton(.goUp)
            menuButton(.goBack)
            menuButton(.goForward)
            menuButton(.refresh)
            
            Divider()
            
            // ═══════════════════════════════════════════
            // SECTION 2: Create
            // ═══════════════════════════════════════════
            menuButton(.newFolder)
            menuButton(.newFile)
            
            Divider()
            
            // ═══════════════════════════════════════════
            // SECTION 3: Clipboard
            // ═══════════════════════════════════════════
            menuButton(.paste)
            
            Divider()
            
            // ═══════════════════════════════════════════
            // SECTION 4: Sort submenu
            // ═══════════════════════════════════════════
            Menu {
                menuButton(.sortByName)
                menuButton(.sortByDate)
                menuButton(.sortBySize)
                menuButton(.sortByType)
            } label: {
                Label("Sort By", systemImage: "arrow.up.arrow.down")
            }
            
            Divider()
            
            // ═══════════════════════════════════════════
            // SECTION 5: Open in external apps
            // ═══════════════════════════════════════════
            menuButton(.openInFinder)
            menuButton(.openInTerminal)
            
            Divider()
            
            // ═══════════════════════════════════════════
            // SECTION 6: Info
            // ═══════════════════════════════════════════
            menuButton(.getInfo)
        }
    }
    
    // MARK: - Menu Button Builder
    
    @ViewBuilder
    private func menuButton(_ action: PanelBackgroundAction) -> some View {
        Button {
            log.debug("\(#function) action=\(action.rawValue) panel=\(panelSide) path='\(currentPath.lastPathComponent)'")
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
    
    private func isActionDisabled(_ action: PanelBackgroundAction) -> Bool {
        switch action {
        case .paste:
            return !ClipboardManager.shared.hasContent
        case .goUp:
            // Disable if already at root
            return currentPath.path == "/"
        case .goBack, .goForward:
            // TODO: Implement history tracking
            return true
        default:
            return false
        }
    }
}

// MARK: - Preview
#Preview {
    VStack {
        Text("Right-click for panel menu")
    }
    .frame(width: 300, height: 200)
    .contextMenu {
        PanelBackgroundContextMenu(
            panelSide: .left,
            currentPath: URL(fileURLWithPath: "/Users"),
            onAction: { action in
                print("Action: \(action)")
            }
        )
    }
}
