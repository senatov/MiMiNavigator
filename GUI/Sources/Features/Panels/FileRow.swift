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

    private var isParentEntry: Bool {
        ParentDirectoryEntry.isParentEntry(file)
    }
    
    private var isMarked: Bool {
        appState.isMarked(file, on: panelSide)
    }

    private var isValidDropTarget: Bool {
        file.isDirectory || file.isSymbolicDirectory
    }

    var body: some View {
        rowContainer
            .id("\(panelSide)_\(file.id)")
    }

    // MARK: - Main Container
    private var rowContainer: some View {
        Group {
            if isParentEntry {
                // ".." entry — simple, no drag-drop, no context menu
                stableContent
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: FilePanelStyle.rowHeight)
                    .contentShape(Rectangle())
                    .help("Navigate to parent directory")
                    .simultaneousGesture(doubleTapGesture)
                    .simultaneousGesture(singleTapGesture)
                    .animation(nil, value: isSelected)
            } else {
                // Normal file row — full drag-drop + context menu
                stableContent
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: FilePanelStyle.rowHeight)
                    .contentShape(Rectangle())
                    .help(makeHelpTooltip())
                    .simultaneousGesture(doubleTapGesture)
                    .simultaneousGesture(singleTapGesture)
                    .animation(nil, value: isSelected)
                    .contextMenu { contextMenuContent }
                    .draggable(file) {
                        makeDragPreview()
                    }
                    .modifier(
                        DropTargetModifier(
                            isValidTarget: isValidDropTarget,
                            isDropTargeted: $isDropTargeted,
                            onDrop: handleDrop,
                            onTargetChange: handleDropTargeting
                        ))
            }
        }
    }

    private var stableContent: some View {
        StableKeyView(file.id.hashValue ^ (isSelected ? 1 : 0) ^ (isActivePanel ? 2 : 0) ^ (isDropTargeted ? 4 : 0) ^ (isMarked ? 8 : 0)) {
            ZStack(alignment: .leading) {
                zebraBackground
                highlightLayer
                rowContent
            }
        }
    }

    private var doubleTapGesture: some Gesture {
        TapGesture(count: 2).onEnded { handleDoubleClick() }
    }

    private var singleTapGesture: some Gesture {
        TapGesture(count: 1).onEnded { handleSingleClick() }
    }

    // MARK: - Extracted Views

    private var zebraBackground: some View {
        let zebraColors = NSColor.alternatingContentBackgroundColors
        return Color(nsColor: zebraColors[index % zebraColors.count])
            .allowsHitTesting(false)
    }

    @ViewBuilder
    private var highlightLayer: some View {
        if isDropTargeted && isValidDropTarget {
            Rectangle()
                .fill(SelectionColors.dropTargetFill)
                .overlay(
                    Rectangle()
                        .stroke(SelectionColors.dropTargetBorder, lineWidth: 2)
                )
                .allowsHitTesting(false)
        } else if isSelected {
            Rectangle()
                .fill(isActivePanel ? SelectionColors.activeFill : SelectionColors.inactiveFill)
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private var contextMenuContent: some View {
        if file.isDirectory {
            DirectoryContextMenu(file: file, panelSide: panelSide) { action in
                logContextMenuAction(action, isDirectory: true)
                onDirectoryAction(action, file)
            }
        } else {
            FileContextMenu(file: file, panelSide: panelSide) { action in
                logContextMenuAction(action, isDirectory: false)
                onFileAction(action, file)
            }
        }
    }

    private func makeDragPreview() -> DragPreviewView {
        DragPreviewView(file: file)
    }

    // MARK: - Event Handlers

    private func handleSingleClick() {
        log.debug("[FileRow] single-click on '\(file.nameStr)' panel=\(panelSide)")
        onSelect(file)
    }

    private func handleDoubleClick() {
        log.debug("[FileRow] double-click on '\(file.nameStr)' isDir=\(file.isDirectory)")
        onDoubleClick(file)
    }

    private func handleDropTargeting(_ targeted: Bool) {
        guard isValidDropTarget else { return }
        log.verbose("[FileRow] drop target '\(file.nameStr)' targeted=\(targeted)")
        withAnimation(.easeInOut(duration: 0.15)) {
            isDropTargeted = targeted
        }
        if targeted {
            dragDropManager.setDropTarget(file.urlValue)
        }
    }

    private func logContextMenuAction(_ action: Any, isDirectory: Bool) {
        let type = isDirectory ? "directory" : "file"
        log.debug("[FileRow] \(type) context menu action=\(action) file='\(file.nameStr)'")
    }

    // MARK: - Handle drop on this row (directory)
    private func handleDrop(_ droppedFiles: [CustomFile]) -> Bool {
        log.info("[FileRow] handleDrop on '\(file.nameStr)' validTarget=\(isValidDropTarget) droppedCount=\(droppedFiles.count)")

        guard isValidDropTarget else {
            log.warning("[FileRow] handleDrop rejected: not a valid drop target")
            return false
        }
        guard !droppedFiles.isEmpty else {
            log.warning("[FileRow] handleDrop rejected: no files dropped")
            return false
        }

        let droppedPaths = Set(droppedFiles.map { $0.urlValue.path })
        if droppedPaths.contains(file.urlValue.path) {
            log.warning("[FileRow] handleDrop rejected: cannot drop onto self")
            return false
        }

        log.info("[FileRow] handleDrop accepted: transferring \(droppedFiles.count) files to '\(file.nameStr)'")
        dragDropManager.prepareTransfer(files: droppedFiles, to: file.urlValue, from: panelSide)
        return true
    }

    // MARK: - Column colors - Finder style (gray secondary text, dimmer for hidden)
    private var secondaryTextColor: Color {
        if isSelected && isActivePanel {
            return .white
        }
        if file.isHidden {
            return Color(#colorLiteral(red: 0.3767382812, green: 0.3767382812, blue: 0.3767382812, alpha: 1))  // Brighter bluish gray
        }
        return Color(nsColor: .secondaryLabelColor)
    }

    // MARK: - System font (Finder style)
    private var columnFont: Font {
        .system(size: 12)
    }

    // MARK: - Row content with columns and separators (aligned with header)
    private var rowContent: some View {
        HStack(alignment: .center, spacing: 0) {
            // Name column (flexible) - matches header
            FileRowView(file: file, isSelected: isSelected, isActivePanel: isActivePanel, isMarked: isMarked)
                .frame(minWidth: 60, maxWidth: .infinity, alignment: .leading)

            ColumnSeparator()

            // Size column - matches header width
            Text(file.fileSizeFormatted)
                .font(columnFont)
                .foregroundStyle(secondaryTextColor)
                .lineLimit(1)
                .frame(width: sizeColumnWidth, alignment: .trailing)
                .padding(.trailing, 8)

            ColumnSeparator()

            // Date column - matches header width
            Text(file.modifiedDateFormatted)
                .font(columnFont)
                .foregroundStyle(secondaryTextColor)
                .lineLimit(1)
                .frame(width: dateColumnWidth, alignment: .leading)
                .padding(.horizontal, 6)

            ColumnSeparator()

            // Permissions column - matches header width
            Text(file.permissionsFormatted)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(secondaryTextColor)
                .lineLimit(1)
                .frame(width: permissionsColumnWidth, alignment: .leading)
                .padding(.horizontal, 6)

            ColumnSeparator()

            // Owner column - matches header width
            Text(file.ownerFormatted)
                .font(columnFont)
                .foregroundStyle(secondaryTextColor)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: ownerColumnWidth, alignment: .leading)
                .padding(.horizontal, 6)

            ColumnSeparator()

            // Type column - matches header width
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

