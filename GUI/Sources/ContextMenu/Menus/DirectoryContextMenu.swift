//
// DirectoryContextMenu.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 08.10.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import SwiftUI

/// Context menu for directory items.
struct DirectoryContextMenu: View {
    let file: CustomFile
    let panelSide: PanelSide
    let onAction: (DirectoryAction) -> Void
    
    var body: some View {
        Group {
            // Navigation section
            menuButton(.open)
            menuButton(.openInNewTab)
            menuButton(.openInFinder)
            menuButton(.openInTerminal)
            menuButton(.viewLister)
            
            Divider()
            
            // Edit section
            menuButton(.cut)
            menuButton(.copy)
            menuButton(.paste)
            
            Divider()
            
            // Operations section
            menuButton(.pack)
            menuButton(.createLink)
            
            Divider()
            
            // Danger zone
            menuButton(.rename)
            menuButton(.delete)
            
            Divider()
            
            // Info
            menuButton(.properties)
        }
    }

    @ViewBuilder
    private func menuButton(_ action: DirectoryAction) -> some View {
        Button {
            log.debug("Directory context action: \(action.rawValue) → \(file.pathStr)")
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
        .disabled(action == .paste && !ClipboardManager.shared.hasContent)
    }
}

// MARK: - Preview
#Preview {
    VStack {
        Text("Right-click for menu")
    }
    .frame(width: 300, height: 200)
    .contextMenu {
        DirectoryContextMenu(
            file: CustomFile(path: "/Users"),
            panelSide: .left,
            onAction: { _ in }
        )
    }
}
