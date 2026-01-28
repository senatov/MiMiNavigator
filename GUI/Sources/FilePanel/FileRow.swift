// FileRow.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 23.10.2024.
//  Copyright © 2024 Senatov. All rights reserved.

import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Lightweight row view for file list with drag-drop support
struct FileRow: View {
    let index: Int
    let file: CustomFile
    let isSelected: Bool
    let panelSide: PanelSide
    let sizeColumnWidth: CGFloat
    let dateColumnWidth: CGFloat
    let typeColumnWidth: CGFloat
    let permissionsColumnWidth: CGFloat
    let ownerColumnWidth: CGFloat
    let onSelect: (CustomFile) -> Void
    let onDoubleClick: (CustomFile) -> Void
    let onFileAction: (FileAction, CustomFile) -> Void
    let onDirectoryAction: (DirectoryAction, CustomFile) -> Void
    @Environment(AppState.self) var appState
    @Environment(DragDropManager.self) var dragDropManager
    
    @State private var isDropTargeted: Bool = false
    
    // MARK: - Selection colors (macOS native style)
    private enum SelectionColors {
        static let activeFill = Color(nsColor: .selectedContentBackgroundColor)
        static let inactiveFill = Color(nsColor: .unemphasizedSelectedContentBackgroundColor)
        static let dropTargetFill = Color.accentColor.opacity(0.2)
        static let dropTargetBorder = Color.accentColor
    }
    
    private var isActivePanel: Bool {
        appState.focusedPanel == panelSide
    }
    
    private var isValidDropTarget: Bool {
        file.isDirectory || file.isSymbolicDirectory
    }

    var body: some View {
        StableBy(file.id.hashValue ^ (isSelected ? 1 : 0) ^ (isActivePanel ? 2 : 0) ^ (isDropTargeted ? 4 : 0)) {
            ZStack(alignment: .leading) {
                // Zebra stripes
                let zebraColors = NSColor.alternatingContentBackgroundColors
                Color(nsColor: zebraColors[index % zebraColors.count])
                    .allowsHitTesting(false)

                // Drop target highlight (for directories)
                if isDropTargeted && isValidDropTarget {
                    Rectangle()
                        .fill(SelectionColors.dropTargetFill)
                        .overlay(
                            Rectangle()
                                .stroke(SelectionColors.dropTargetBorder, lineWidth: 2)
                        )
                        .allowsHitTesting(false)
                }
                // Selection highlight - macOS native style (solid fill, no border, no rounded corners)
                else if isSelected {
                    Rectangle()
                        .fill(isActivePanel ? SelectionColors.activeFill : SelectionColors.inactiveFill)
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
                DirectoryContextMenu(file: file, panelSide: panelSide) { action in
                    onDirectoryAction(action, file)
                }
            } else {
                FileContextMenu(file: file, panelSide: panelSide) { action in
                    onFileAction(action, file)
                }
            }
        }
        // MARK: - Drag support
        .draggable(file) {
            DragPreviewView(file: file)
        }
        // MARK: - Drop support (only for directories)
        .dropDestination(for: CustomFile.self) { droppedFiles, _ in
            handleDrop(droppedFiles)
        } isTargeted: { targeted in
            if isValidDropTarget {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isDropTargeted = targeted
                }
                if targeted {
                    dragDropManager.setDropTarget(file.urlValue)
                }
            }
        }
        .id("\(panelSide)_\(file.id)")
    }
    
    // MARK: - Handle drop on this row (directory)
    private func handleDrop(_ droppedFiles: [CustomFile]) -> Bool {
        guard isValidDropTarget else { return false }
        guard !droppedFiles.isEmpty else { return false }
        
        let droppedPaths = Set(droppedFiles.map { $0.urlValue.path })
        if droppedPaths.contains(file.urlValue.path) { return false }
        
        dragDropManager.prepareTransfer(files: droppedFiles, to: file.urlValue, from: panelSide)
        return true
    }

    // MARK: - Column colors - Finder style (gray secondary text)
    private var secondaryTextColor: Color {
        (isSelected && isActivePanel) ? .white : Color(nsColor: .secondaryLabelColor)
    }
    
    // MARK: - System font (Finder style)
    private var columnFont: Font {
        .system(size: 12)
    }

    // MARK: - Row content with columns
    private var rowContent: some View {
        HStack(alignment: .center, spacing: 0) {
            // Name column (flexible) - can shrink
            FileRowView(file: file, isSelected: isSelected, isActivePanel: isActivePanel)
                .frame(minWidth: 60, maxWidth: .infinity, alignment: .leading)
            
            // Size column
            Text(file.fileSizeFormatted)
                .font(columnFont)
                .foregroundStyle(secondaryTextColor)
                .lineLimit(1)
                .frame(width: sizeColumnWidth, alignment: .trailing)
                .padding(.trailing, 8)
            
            // Date column
            Text(file.modifiedDateFormatted)
                .font(columnFont)
                .foregroundStyle(secondaryTextColor)
                .lineLimit(1)
                .frame(width: dateColumnWidth, alignment: .leading)
                .padding(.horizontal, 6)
            
            // Permissions column
            Text(file.permissionsFormatted)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(secondaryTextColor)
                .lineLimit(1)
                .frame(width: permissionsColumnWidth, alignment: .leading)
                .padding(.horizontal, 6)
            
            // Owner column
            Text(file.ownerFormatted)
                .font(columnFont)
                .foregroundStyle(secondaryTextColor)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: ownerColumnWidth, alignment: .leading)
                .padding(.horizontal, 6)
            
            // Type column
            Text(file.fileTypeDisplay)
                .font(columnFont)
                .foregroundStyle(secondaryTextColor)
                .frame(width: typeColumnWidth, alignment: .leading)
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.horizontal, 6)
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
    }
    
    private func makeHelpTooltip() -> String {
        let icon = file.isDirectory ? "📁" : "📄"
        return "\(icon) \(file.nameStr)\n📍 \(file.pathStr)\n📅 \(file.modifiedDateFormatted)\n📦 \(file.fileSizeFormatted)"
    }
}

// MARK: - Drag preview view
struct DragPreviewView: View {
    let file: CustomFile
    
    var body: some View {
        HStack(spacing: 8) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: file.urlValue.path))
                .resizable()
                .frame(width: 32, height: 32)
            
            Text(file.nameStr)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        )
    }
}
