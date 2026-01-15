//
// FileRowView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 11.08.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import AppKit
import SwiftUI

// MARK: - File row content view (icon + name)
// Note: Selection background is handled by parent FileRow
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

    // MARK: - Text color for the file name based on file attributes and selection
    private var nameColor: Color {
        // White text on blue selection background (active panel)
        if isSelected && isActivePanel {
            return .white
        }
        // Standard colors for non-selected or inactive panel
        if file.isSymbolicDirectory { return FilePanelStyle.blueSymlinkDirNameColor }
        if file.isDirectory { return FilePanelStyle.dirNameColor }
        return .primary
    }

    // MARK: - Base content for a single file row (icon + name)
    private func baseContent() -> some View {
        HStack(spacing: 8) {
            // File icon with optional symlink badge - bigger and brighter
            ZStack(alignment: .bottomLeading) {
                // Get system icon for the file
                Image(nsImage: getEnhancedIcon(for: file))
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .frame(width: RowDesignTokens.iconSize, height: RowDesignTokens.iconSize)
                    .shadow(color: .black.opacity(0.15), radius: 1.2, x: 0.5, y: 1)
                    .brightness(0.12)   // More vivid
                    .saturation(1.35)   // Richer colors
                    .contrast(1.08)     // Crisper edges
                
                // Symlink badge
                if file.isSymbolicLink {
                    Image(systemName: "arrowshape.turn.up.right.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: RowDesignTokens.iconSize / 2.5, height: RowDesignTokens.iconSize / 2.5)
                        .foregroundStyle(.orange)
                        .shadow(color: .black.opacity(0.3), radius: 0.5, x: 0.5, y: 0.5)
                        .offset(x: -2, y: 2)
                }
            }
            .allowsHitTesting(false)
            
            // File name
            Text(file.nameStr)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(nameColor)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
    
    // MARK: - Get enhanced icon for file
    private func getEnhancedIcon(for file: CustomFile) -> NSImage {
        let icon = NSWorkspace.shared.icon(forFile: file.urlValue.path)
        // Request larger size for better quality
        icon.size = NSSize(width: 32, height: 32)
        return icon
    }
}
