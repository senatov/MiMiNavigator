// FileRow.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 23.10.2024.
//  Copyright © 2024 Senatov. All rights reserved.
//

import AppKit
import SwiftUI

// MARK: - Lightweight row view for file list
struct FileRow: View {
    let index: Int
    let file: CustomFile
    let isSelected: Bool
    let panelSide: PanelSide
    let onSelect: (CustomFile) -> Void
    let onDoubleClick: (CustomFile) -> Void
    let onFileAction: (FileAction, CustomFile) -> Void
    let onDirectoryAction: (DirectoryAction, CustomFile) -> Void
    @Environment(AppState.self) var appState
    
    // MARK: - Selection colors (macOS native style)
    private enum SelectionColors {
        static let activeFill = Color(nsColor: .selectedContentBackgroundColor)
        static let activeBorder = Color(nsColor: .keyboardFocusIndicatorColor).opacity(0.6)
        static let inactiveFill = Color(nsColor: .unemphasizedSelectedContentBackgroundColor)
        static let inactiveBorder = Color(nsColor: .separatorColor)
    }
    
    private var isActivePanel: Bool {
        appState.focusedPanel == panelSide
    }

    var body: some View {
        StableBy(file.id.hashValue ^ (isSelected ? 1 : 0) ^ (isActivePanel ? 2 : 0)) {
            ZStack(alignment: .leading) {
                // Zebra stripes
                let zebraColors = NSColor.alternatingContentBackgroundColors
                Color(nsColor: zebraColors[index % zebraColors.count])
                    .allowsHitTesting(false)

                // Selection highlight
                if isSelected {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(isActivePanel ? SelectionColors.activeFill : SelectionColors.inactiveFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .stroke(isActivePanel ? SelectionColors.activeBorder : SelectionColors.inactiveBorder, lineWidth: 1)
                        )
                        .allowsHitTesting(false)
                }

                rowContent
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: FilePanelStyle.rowHeight)
        .contentShape(Rectangle())
        .help(makeHelpTooltip())
        .simultaneousGesture(
            TapGesture(count: 2).onEnded { onDoubleClick(file) }
        )
        .simultaneousGesture(
            TapGesture(count: 1).onEnded { onSelect(file) }
        )
        .animation(nil, value: isSelected)
        .contextMenu {
            if file.isDirectory {
                DirectoryContextMenu(file: file) { action in
                    onDirectoryAction(action, file)
                }
            } else {
                FileContextMenu(file: file) { action in
                    onFileAction(action, file)
                }
            }
        }
        .id("\(panelSide)_\(file.id)")
    }

    // MARK: - Secondary text colors
    private var secondaryTextColor: Color {
        (isSelected && isActivePanel) ? .white.opacity(0.85) : Color(nsColor: .secondaryLabelColor)
    }
    
    private var tertiaryTextColor: Color {
        (isSelected && isActivePanel) ? .white.opacity(0.7) : Color(nsColor: .tertiaryLabelColor)
    }
    
    private var typeTextColor: Color {
        if isSelected && isActivePanel { return .white.opacity(0.75) }
        if file.isDirectory || file.isSymbolicDirectory {
            return Color(nsColor: .systemBlue).opacity(0.8)
        }
        return Color(nsColor: .tertiaryLabelColor)
    }

    // MARK: - Row content with columns
    private var rowContent: some View {
        HStack(alignment: .center, spacing: 4) {
            // Name column
            FileRowView(file: file, isSelected: isSelected, isActivePanel: isActivePanel)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            columnDivider
            
            // Size column
            Text(file.fileSizeFormatted)
                .font(.system(size: 11))
                .foregroundStyle(secondaryTextColor)
                .frame(width: FilePanelStyle.sizeColumnWidth, alignment: .trailing)
            
            columnDivider
            
            // Date column
            Text(file.modifiedDateFormatted)
                .font(.system(size: 11))
                .foregroundStyle(tertiaryTextColor)
                .frame(width: FilePanelStyle.modifiedColumnWidth, alignment: .leading)
            
            columnDivider
            
            // Type column
            Text(file.fileTypeDisplay)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(typeTextColor)
                .frame(width: FilePanelStyle.typeColumnWidth, alignment: .leading)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.vertical, 1)
        .padding(.horizontal, 4)
    }
    
    private var columnDivider: some View {
        Rectangle()
            .frame(width: 1)
            .foregroundStyle(Color(nsColor: .separatorColor).opacity(0.4))
            .padding(.vertical, 2)
    }

    private func makeHelpTooltip() -> String {
        let icon = file.isDirectory ? "📁" : "📄"
        return "\(icon) \(file.nameStr)\n📍 \(file.pathStr)\n📅 \(file.modifiedDateFormatted)\n📦 \(file.fileSizeFormatted)"
    }
}
