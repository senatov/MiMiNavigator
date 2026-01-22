//
// FileContextMenu.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 08.10.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import SwiftUI

/// Context menu for file items (non-directory).
struct FileContextMenu: View {
    let file: CustomFile
    let panelSide: PanelSide
    let onAction: (FileAction) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Group {
            // Open section
            menuButton(.open)
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
    private func menuButton(_ action: FileAction) -> some View {
        Button {
            log.debug("File context action: \(action.rawValue) → \(file.pathStr)")
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
        FileContextMenu(
            file: CustomFile(path: "/test/document.txt"),
            panelSide: .left,
            onAction: { _ in }
        )
    }
}
