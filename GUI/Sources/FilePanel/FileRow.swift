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
        static let activeBorder = Color(nsColor: .keyboardFocusIndicatorColor).opacity(0.6)
        static let inactiveFill = Color(nsColor: .unemphasizedSelectedContentBackgroundColor)
        static let inactiveBorder = Color(nsColor: .separatorColor)
        static let dropTargetFill = Color.accentColor.opacity(0.2)
        static let dropTargetBorder = Color.accentColor
    }
    
    private var isActivePanel: Bool {
        appState.focusedPanel == panelSide
    }
    
    /// Check if this row is a valid drop target (must be a directory)
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
                    RoundedRectangle(cornerRadius: FilePanelStyle.rowSelectionRadius, style: .continuous)
                        .fill(SelectionColors.dropTargetFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: FilePanelStyle.rowSelectionRadius, style: .continuous)
                                .stroke(SelectionColors.dropTargetBorder, lineWidth: 2)
                        )
                        .allowsHitTesting(false)
                }
                // Selection highlight
                else if isSelected {
                    RoundedRectangle(cornerRadius: FilePanelStyle.rowSelectionRadius, style: .continuous)
                        .fill(isActivePanel ? SelectionColors.activeFill : SelectionColors.inactiveFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: FilePanelStyle.rowSelectionRadius, style: .continuous)
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
        // MARK: - Drag support
        .draggable(file) {
            DragPreviewView(file: file)
        }
        // MARK: - Drop support (only for directories)
        .dropDestination(for: CustomFile.self) { droppedFiles, location in
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
        guard isValidDropTarget else {
            log.debug("FileRow: drop rejected - not a directory: \(file.nameStr)")
            return false
        }
        
        guard !droppedFiles.isEmpty else {
            log.debug("FileRow: drop rejected - no files")
            return false
        }
        
        // Don't allow dropping on self
        let droppedPaths = Set(droppedFiles.map { $0.urlValue.path })
        if droppedPaths.contains(file.urlValue.path) {
            log.debug("FileRow: drop rejected - cannot drop on self")
            return false
        }
        
        log.debug("FileRow: preparing transfer of \(droppedFiles.count) items to \(file.nameStr)")
        dragDropManager.prepareTransfer(
            files: droppedFiles,
            to: file.urlValue,
            from: panelSide
        )
        return true
    }

    // MARK: - Column colors (from FilePanelStyle)
    private var sizeColumnColor: Color {
        (isSelected && isActivePanel) ? .white : FilePanelStyle.sizeColumnColor
    }
    
    private var dateColumnColor: Color {
        (isSelected && isActivePanel) ? .white : FilePanelStyle.dateColumnColor
    }
    
    private var typeColumnColor: Color {
        (isSelected && isActivePanel) ? .white : FilePanelStyle.typeColumnColor
    }
    
    // MARK: - SF Pro Display Regular font
    private func columnFont(size: CGFloat) -> Font {
        .custom("SF Pro Display", size: size).weight(.regular)
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
            .fill(FilePanelStyle.columnDividerColor)
            .frame(width: max(width, 1.0))
            .padding(.vertical, 2)
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
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        )
    }
}
