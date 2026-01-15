// FileRowView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 11.08.2024.
//  Copyright © 2024 Senatov. All rights reserved.

import AppKit
import SwiftUI

// MARK: - File row content view (icon + name)
struct FileRowView: View {
    let file: CustomFile
    let isSelected: Bool
    let isActivePanel: Bool

    // MARK: - View Body
    var body: some View {
        baseContent()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, RowDesignTokens.grid / 2)
            .padding(.horizontal, RowDesignTokens.grid)
            .contentShape(Rectangle())
    }

    // MARK: - Text color based on file type and selection state
    private var nameColor: Color {
        if isSelected && isActivePanel {
            return .white
        }
        if file.isSymbolicDirectory { return FilePanelStyle.blueSymlinkDirNameColor }
        if file.isDirectory { return FilePanelStyle.dirNameColor }
        return .primary
    }
    
    // MARK: - Font weight based on file type
    private var nameWeight: Font.Weight {
        if file.isDirectory || file.isSymbolicDirectory {
            return .medium
        }
        return .regular
    }

    // MARK: - Base content for a single file row (icon + name)
    private func baseContent() -> some View {
        HStack(spacing: 8) {
            // File icon
            ZStack(alignment: .bottomTrailing) {
                Image(nsImage: getIcon(for: file))
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .frame(width: RowDesignTokens.iconSize, height: RowDesignTokens.iconSize)
                    .fixedSize()
                
                // Symlink badge overlay
                if file.isSymbolicLink {
                    Image(systemName: "arrow.turn.up.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(2)
                        .background(
                            Circle()
                                .fill(Color.orange)
                                .shadow(color: .black.opacity(0.3), radius: 1, x: 0.5, y: 0.5)
                        )
                        .offset(x: 3, y: 3)
                }
            }
            .allowsHitTesting(false)
            .layoutPriority(1)
            
            // File name - truncates in middle (macOS style)
            Text(file.nameStr)
                .font(.system(size: 13, weight: nameWeight))
                .foregroundStyle(nameColor)
                .lineLimit(1)
                .truncationMode(.middle)
                .layoutPriority(0)
        }
    }
    
    // MARK: - Get icon for file
    private func getIcon(for file: CustomFile) -> NSImage {
        let icon = NSWorkspace.shared.icon(forFile: file.urlValue.path)
        icon.size = NSSize(width: 32, height: 32)
        return icon
    }
}
