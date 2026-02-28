// FileRow.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 23.10.2024.
//  Copyright © 2024-2026 Senatov. All rights reserved.

import AppKit
import FileModelKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Lightweight row view for file list with drag-drop support
struct FileRow: View {
    let index: Int
    let file: CustomFile
    let isSelected: Bool
    let panelSide: PanelSide
    let layout: ColumnLayoutModel
    let onSelect: (CustomFile) -> Void
    let onDoubleClick: (CustomFile) -> Void
    let onFileAction: (FileAction, CustomFile) -> Void
    let onDirectoryAction: (DirectoryAction, CustomFile) -> Void
    let onMultiSelectionAction: (MultiSelectionAction) -> Void
    @Environment(AppState.self) var appState
    @Environment(DragDropManager.self) var dragDropManager
    @State private var colorStore = ColorThemeStore.shared

    @State private var isDropTargeted: Bool = false

    // MARK: - Selection colors — live from ColorThemeStore
    private enum SelectionColors {
        static var activeFill: Color   { ColorThemeStore.shared.activeTheme.selectionActive }
        static var inactiveFill: Color { ColorThemeStore.shared.activeTheme.selectionInactive }
        static let dropTargetFill  = Color.accentColor.opacity(0.2)
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
                    // tooltip removed — Get Info via context menu is sufficient
                    .simultaneousGesture(doubleTapGesture)
                    .simultaneousGesture(singleTapGesture)
                    .animation(nil, value: isSelected)
            } else {
                // Normal file row — full drag-drop + context menu
                stableContent
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: FilePanelStyle.rowHeight)
                    .contentShape(Rectangle())
                    // tooltip removed — Get Info via context menu is sufficient
                    .simultaneousGesture(doubleTapGesture)
                    .simultaneousGesture(singleTapGesture)
                    .animation(nil, value: isSelected)
                    .contextMenu { contextMenuContent }
                    .onDrag {
                        let filesToDrag = dragFiles
                        dragDropManager.startDrag(files: filesToDrag, from: panelSide)
                        // Create NSItemProvider with all dragged file URLs
                        let provider = NSItemProvider()
                        for f in filesToDrag {
                            provider.registerFileRepresentation(
                                forTypeIdentifier: "public.file-url",
                                visibility: .all
                            ) { completion in
                                completion(f.urlValue, true, nil)
                                return nil
                            }
                        }
                        return provider
                    } preview: {
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
        StableKeyView(
            file.id.hashValue ^ (isSelected ? 1 : 0) ^ (isActivePanel ? 2 : 0) ^ (isDropTargeted ? 4 : 0) ^ (isMarked ? 8 : 0)
        ) {
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
        if isParentEntry {
            // ".." row — fixed light grey background regardless of zebra index
            return AnyView(
                Color(nsColor: .systemGray).opacity(0.13)
                    .allowsHitTesting(false))
        }
        if isActivePanel {
            // Active panel: warm white base with subtle zebra stripe
            let isOdd = index % 2 == 1
            return AnyView(
                DesignTokens.warmWhite
                    .overlay(Color.black.opacity(isOdd ? 0.02 : 0))
                    .allowsHitTesting(false))
        }
        let zebraColors = NSColor.alternatingContentBackgroundColors
        return AnyView(
            Color(nsColor: zebraColors[index % zebraColors.count])
                .allowsHitTesting(false))
    }

    @ViewBuilder
    private var highlightLayer: some View {
        if isDropTargeted && isValidDropTarget {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(SelectionColors.dropTargetFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(SelectionColors.dropTargetBorder, lineWidth: 2)
                )
                .padding(.horizontal, 4)
                .allowsHitTesting(false)
        } else if isSelected {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isActivePanel ? SelectionColors.activeFill : SelectionColors.inactiveFill)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .allowsHitTesting(false)
        }
    }

    /// True when there are marked files on this panel (show group menu)
    private var hasMarkedFiles: Bool {
        appState.markedCount(for: panelSide) > 0
    }

    @ViewBuilder
    private var contextMenuContent: some View {
        if hasMarkedFiles {
            // Group context menu for marked files
            MultiSelectionContextMenu(
                markedCount: appState.markedCount(for: panelSide),
                panelSide: panelSide
            ) { action in
                log.debug("[FileRow] multi-selection action=\(action.rawValue) count=\(appState.markedCount(for: panelSide))")
                onMultiSelectionAction(action)
            }
        } else if file.isDirectory {
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

    /// Files to drag: all marked files if this file is marked, otherwise just this file
    private var dragFiles: [CustomFile] {
        let marked = appState.markedCustomFiles(for: panelSide)
        // If this file is in the marked set, drag all marked files
        if !marked.isEmpty && marked.contains(where: { $0.id == file.id }) {
            return marked
        }
        // If file is not marked but marks exist, drag only this file
        // If no marks at all, drag this file
        return [file]
    }

    private func makeDragPreview() -> DragPreviewView {
        let files = dragFiles
        if files.count > 1 {
            return DragPreviewView(file: file, additionalCount: files.count - 1)
        }
        return DragPreviewView(file: file)
    }

    // MARK: - Event Handlers

    private func handleSingleClick() {
        // Detect modifier keys from current NSEvent
        let modifiers = Self.currentClickModifiers()
        log.debug("[FileRow] single-click on '\(file.nameStr)' panel=\(panelSide) modifiers=\(modifiers)")

        // Always select the file (updates cursor position)
        onSelect(file)

        // Handle multi-selection via modifier keys
        appState.handleClickWithModifiers(on: file, modifiers: modifiers)
    }

    /// Read modifier keys from the current NSEvent
    private static func currentClickModifiers() -> ClickModifiers {
        guard let event = NSApp.currentEvent else { return .none }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags.contains(.command) {
            return .command
        } else if flags.contains(.shift) {
            return .shift
        }
        return .none
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

    // MARK: - Column colors - per-column accent when not selected, white when selected+active
    private func cellColor(for col: ColumnID) -> Color {
        if isParentEntry { return Color(nsColor: .systemGray).opacity(0.6) }
        if file.isHidden { return Color(#colorLiteral(red: 0.3767382812, green: 0.3767382812, blue: 0.3767382812, alpha: 1)) }
        return col.columnColor
    }

    // MARK: - System font (Finder style)
    private var columnFont: Font {
        .system(size: 12)
    }

    // MARK: - Row content — driven by ColumnLayoutModel
    private var rowContent: some View {
        let fixedCols = layout.visibleColumns.filter { $0.id != .name }

        return HStack(alignment: .center, spacing: 0) {
            // Name — flexible
            FileRowView(file: file, isSelected: isSelected, isActivePanel: isActivePanel, isMarked: isMarked)
                .frame(minWidth: 60, maxWidth: .infinity, alignment: .leading)
                .clipped()

            // Fixed columns — separator before each, indices for reliable rendering
            ForEach(fixedCols.indices, id: \.self) { i in
                let spec = fixedCols[i]
                ColumnSeparator()
                cellText(for: spec.id)
                    .font(spec.id == .permissions ? .system(size: 11, design: .monospaced) : columnFont)
                    .foregroundStyle(cellColor(for: spec.id))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    // leading padding only: trailing side is covered by next separator
                    .frame(width: spec.width, alignment: spec.id.alignment)
                    .padding(.leading, TableColumnDefaults.cellPadding)
                    .padding(.trailing, TableColumnDefaults.cellPadding)
            }
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private func cellText(for col: ColumnID) -> some View {
        switch col {
            case .name: EmptyView()
            case .dateModified: Text(file.modifiedDateFormatted)
            case .size: Text(file.fileSizeFormatted)
            case .kind: KindCell(file: file)
            case .permissions: Text(file.permissionsFormatted)
            case .owner: Text(file.ownerFormatted)
            case .childCount: Text(file.childCountFormatted)
            case .dateCreated: Text(file.creationDateFormatted)
            case .dateLastOpened: Text(file.lastOpenedFormatted)
            case .dateAdded: Text(file.dateAddedFormatted)
            case .group: Text(file.groupNameFormatted)
        }
    }

}

// MARK: - Kind column cell
/// Shows a multicolor folder SF Symbol for directories, plain text for files.
private struct KindCell: View {
    let file: CustomFile
    var body: some View {
        if file.isDirectory || file.isSymbolicDirectory {
            Image(systemName: file.isSymbolicDirectory ? "folder.badge.questionmark" : "folder.fill")
                .symbolRenderingMode(.multicolor)
                .font(.system(size: 12, weight: .regular))
        } else if file.isSymbolicLink {
            Image(systemName: "arrow.up.right.square")
                .symbolRenderingMode(.multicolor)
                .font(.system(size: 12, weight: .regular))
        } else {
            Text(file.kindFormatted)
        }
    }
}
