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
        if file.isSymbolicDirectory { return FilePanelStyle.fileNameColor }
        if file.isDirectory { return FilePanelStyle.dirNameColor }
        return .primary
    }

    // MARK: - Base content for a single file row (icon + name)
    private func baseContent() -> some View {
        HStack(spacing: 6) {
            // File icon with optional symlink badge
            ZStack(alignment: .bottomLeading) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: file.urlValue.path))
                    .resizable()
                    .interpolation(.medium)
                    .antialiased(true)
                    .frame(width: RowDesignTokens.iconSize, height: RowDesignTokens.iconSize)
                    .shadow(color: .black.opacity(0.08), radius: 0.5, x: 1, y: 1)
                
                if file.isSymbolicDirectory {
                    Image(systemName: "arrowshape.turn.up.right.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: RowDesignTokens.iconSize / 3, height: RowDesignTokens.iconSize / 3)
                        .foregroundStyle(.orange)
                        .shadow(color: .black.opacity(0.08), radius: 0.5, x: 1, y: 1)
                }
            }
            .allowsHitTesting(false)
            
            // File name
            Text(file.nameStr)
                .font(.system(size: 13, weight: .regular, design: .default))
                .foregroundStyle(nameColor)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

