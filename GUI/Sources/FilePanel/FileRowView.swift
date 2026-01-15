// FileRowView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 11.08.2024.
//  Copyright © 2024 Senatov. All rights reserved.
//

import AppKit
import SwiftUI

// MARK: - File row content view (icon + name)
// Styled similar to Total Commander for clarity and visual appeal
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
        // White text on blue selection background (active panel)
        if isSelected && isActivePanel {
            return .white
        }
        // Standard colors for non-selected or inactive panel
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
            // File icon - Total Commander style: larger, crisp, clear
            ZStack(alignment: .bottomTrailing) {
                // Main icon
                Image(nsImage: getTotalCommanderStyleIcon(for: file))
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .frame(width: RowDesignTokens.iconSize, height: RowDesignTokens.iconSize)
                
                // Symlink badge overlay (small arrow in corner)
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
            
            // File name with appropriate styling
            Text(file.nameStr)
                .font(.system(size: 13, weight: nameWeight))
                .foregroundStyle(nameColor)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
    
    // MARK: - Get icon styled like Total Commander
    private func getTotalCommanderStyleIcon(for file: CustomFile) -> NSImage {
        let icon: NSImage
        
        // For directories, use folder icon
        if file.isDirectory || file.isSymbolicDirectory {
            if file.isSymbolicLink {
                // Symlink to directory - use alias folder icon
                icon = NSWorkspace.shared.icon(forFile: file.urlValue.path)
            } else {
                // Regular directory
                icon = NSWorkspace.shared.icon(forFile: file.urlValue.path)
            }
        } else {
            // For files, get the document icon
            icon = NSWorkspace.shared.icon(forFile: file.urlValue.path)
        }
        
        // Request high-quality icon size (32x32 renders crisply at display size)
        icon.size = NSSize(width: 32, height: 32)
        
        // Apply Total Commander style enhancements
        return enhanceIconForTotalCommanderStyle(icon)
    }
    
    // MARK: - Enhance icon to match Total Commander aesthetic
    private func enhanceIconForTotalCommanderStyle(_ original: NSImage) -> NSImage {
        let size = NSSize(width: 32, height: 32)
        let enhanced = NSImage(size: size)
        
        enhanced.lockFocus()
        
        // Draw with slight contrast boost for clarity
        NSGraphicsContext.current?.imageInterpolation = .high
        
        // Draw the original icon
        original.draw(
            in: NSRect(origin: .zero, size: size),
            from: NSRect(origin: .zero, size: original.size),
            operation: .sourceOver,
            fraction: 1.0
        )
        
        enhanced.unlockFocus()
        
        return enhanced
    }
}
