// FileRow.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 23.10.2024.
//  Copyright © 2024 Senatov. All rights reserved.

import AppKit
import SwiftUI

// MARK: - Lightweight row view for file list
struct FileRow: View {
    let index: Int
    let file: CustomFile
    let isSelected: Bool
    let panelSide: PanelSide
    let sizeColumnWidth: CGFloat
    let dateColumnWidth: CGFloat
    let typeColumnWidth: CGFloat
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

    // MARK: - Column colors
    private var sizeColumnColor: Color {
        (isSelected && isActivePanel) ? .white.opacity(0.85) : Color(red: 0.5, green: 0.3, blue: 0.1)  // Brown
    }
    
    private var dateColumnColor: Color {
        (isSelected && isActivePanel) ? .white.opacity(0.85) : Color(red: 0.1, green: 0.4, blue: 0.2)  // Dark green
    }
    
    private var typeColumnColor: Color {
        (isSelected && isActivePanel) ? .white.opacity(0.85) : Color(red: 0.4, green: 0.1, blue: 0.5)  // Dark purple
    }
    
    // MARK: - SF Pro Display Thin font
    private func columnFont(size: CGFloat) -> Font {
        .custom("SF Pro Display", size: size).weight(.thin)
    }

    // MARK: - Row content with columns
    private var rowContent: some View {
        HStack(alignment: .center, spacing: 0) {
            // Name column (flexible) - can shrink
            FileRowView(file: file, isSelected: isSelected, isActivePanel: isActivePanel)
                .frame(minWidth: 60, maxWidth: .infinity, alignment: .leading)
            
            columnDivider
            
            // Size column - brown
            Text(file.fileSizeFormatted)
                .font(columnFont(size: 11))
                .foregroundStyle(sizeColumnColor)
                .lineLimit(1)
                .frame(width: sizeColumnWidth, alignment: .trailing)
                .padding(.horizontal, 4)
            
            columnDivider
            
            // Date column - dark green
            Text(file.modifiedDateFormatted)
                .font(columnFont(size: 11))
                .foregroundStyle(dateColumnColor)
                .lineLimit(1)
                .frame(width: dateColumnWidth, alignment: .leading)
                .padding(.horizontal, 4)
            
            columnDivider
            
            // Type column - dark purple
            Text(file.fileTypeDisplay)
                .font(columnFont(size: 10))
                .foregroundStyle(typeColumnColor)
                .frame(width: typeColumnWidth, alignment: .leading)
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.horizontal, 4)
        }
        .padding(.vertical, 1)
        .padding(.horizontal, 4)
    }
    
    private var columnDivider: some View {
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        let width = 1.0 / scale
        return Rectangle()
            .fill(Color(red: 0.1, green: 0.15, blue: 0.4))
            .frame(width: max(width, 1.0))
            .padding(.vertical, 2)
    }

    private func makeHelpTooltip() -> String {
        let icon = file.isDirectory ? "📁" : "📄"
        return "\(icon) \(file.nameStr)\n📍 \(file.pathStr)\n📅 \(file.modifiedDateFormatted)\n📦 \(file.fileSizeFormatted)"
    }
}
