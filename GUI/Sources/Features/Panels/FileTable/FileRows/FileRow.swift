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
@MainActor
struct FileRow: View, Equatable {

    let index: Int
    let file: CustomFile
    let isSelected: Bool
    let panelSide: FavPanelSide
    let layout: ColumnLayoutModel
    let layoutVersion: Int
    let onSelect: (CustomFile) -> Void
    let onDoubleClick: (CustomFile) -> Void
    let onFileAction: (FileAction, CustomFile) -> Void
    let onDirectoryAction: (DirectoryAction, CustomFile) -> Void
    let onMultiSelectionAction: (MultiSelectionAction) -> Void

    @Environment(AppState.self) var appState
    @Environment(DragDropManager.self) var dragDropManager

    @State private var colorStore = ColorThemeStore.shared
    @State private var isDropTargeted: Bool = false
    @State private var isHoveringParentRow: Bool = false

    /// Shared formatter to avoid repeated ByteCountFormatter allocations during scrolling
    private static let sizeFormatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .file
        f.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        f.includesUnit = true
        // Avoid strings like "Zero KB" – use numeric form instead (e.g. "0 KB")
        f.allowsNonnumericFormatting = false
        return f
    }()
    /// Format size with consistent rules (avoid "0 KB")
    static func formatSize(_ size: Int64) -> String {
        // DirectorySizeService uses a negative sentinel for "unavailable".
        if size < 0 { return "—" }
        if size == 0 { return "0 B" }
        return sizeFormatter.string(fromByteCount: size)
    }
    // MARK: - Equatable optimization
    /// Prevent SwiftUI from re-rendering the row unless the visible state actually changed.
    nonisolated static func == (lhs: FileRow, rhs: FileRow) -> Bool {
        lhs.file.id == rhs.file.id && lhs.isSelected == rhs.isSelected && lhs.panelSide == rhs.panelSide
            && lhs.layoutVersion == rhs.layoutVersion
            && lhs.file.sizeVersion == rhs.file.sizeVersion
            && lhs.file.sizeInBytes == rhs.file.sizeInBytes
            && lhs.file.cachedDirectorySize == rhs.file.cachedDirectorySize
            && lhs.file.cachedShallowSize == rhs.file.cachedShallowSize
            && lhs.file.cachedChildCount == rhs.file.cachedChildCount
            && lhs.file.modifiedDate?.timeIntervalSince1970 == rhs.file.modifiedDate?.timeIntervalSince1970
    }

    private var isActivePanel: Bool {
        appState.focusedPanel == panelSide
    }

    var isParentEntry: Bool {
        // Primary check
        if ParentDirectoryEntry.isParentEntry(file) { return true }

        // Fallback: synthetic parent row may not have the flag
        return file.nameStr == ".."
    }

    private var isMarked: Bool {
        appState.isMarked(file, on: panelSide)
    }

    private var isValidDropTarget: Bool {
        file.isDirectory || file.isSymbolicDirectory
    }

    var body: some View {
        rowContainer
    }

    // MARK: - Main Container
    private var rowContainer: some View {
        Group {
            if isParentEntry {
                parentRowView()
            } else {
                // Normal file row — full drag-drop + context menu
                normalRowView()
            }
        }
    }

    private var stableRowContent: some View {
        StableKeyView(
            file.id.hashValue
                ^ file.sizeVersion.hashValue
                ^ file.sizeInBytes.hashValue
                ^ (file.cachedDirectorySize ?? Int64.min).hashValue
                ^ (file.cachedShallowSize ?? Int64.min).hashValue
                ^ (file.cachedChildCount ?? Int.min).hashValue
                ^ Int(file.modifiedDate?.timeIntervalSince1970 ?? 0).hashValue
        ) {
            rowContent
        }
    }

    private var rowVisualContent: some View {
        ZStack(alignment: .leading) {
            zebraBackground
            if isDropTargetActive {
                dropTargetHighlight
            }
            stableRowContent
        }
    }

    // MARK: - Row Gestures
    private func rowGestures() -> some Gesture {
        SimultaneousGesture(
            TapGesture(count: 2).onEnded { handleDoubleClick() },
            TapGesture(count: 1).onEnded { handleSingleClick() }
        )
    }

    // MARK: - Extracted Views
    @ViewBuilder
    private var zebraBackground: some View {
        if isSelected {
            Color.clear
                .allowsHitTesting(false)
        } else if isParentEntry {
            parentRowBackground
        } else {
            standardRowBackground
        }
    }

    private var parentRowBackground: some View {
        Color(nsColor: .systemGray)
            .opacity(0.13)
            .allowsHitTesting(false)
    }

    private var standardRowBackground: some View {
        let isOdd = index % 2 == 1
        let color: Color =
            isActivePanel
            ? (isOdd ? DesignTokens.zebraActiveOdd : DesignTokens.zebraActiveEven)
            : (isOdd ? DesignTokens.zebraInactiveOdd : DesignTokens.zebraInactiveEven)

        return color.allowsHitTesting(false)
    }

    private var isDropTargetActive: Bool {
        (isDropTargeted || isInternalDropTarget) && isValidDropTarget
    }

    /// True when DragDropManager signals this directory as the hover target during internal drag
    private var isInternalDropTarget: Bool {
        guard isValidDropTarget, !dragDropManager.draggedFiles.isEmpty else { return false }
        return dragDropManager.dropTargetPath == file.urlValue
    }

    private var dropTargetHighlight: some View {
        PulsingDropHighlight()
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(false)
    }

    /// True when there are marked files on this panel (show group menu)
    private var hasMarkedFiles: Bool {
        appState.markedCount(for: panelSide) > 0
    }

    @ViewBuilder
    private var contextMenuContent: some View {
        let optionHeld = NSEvent.modifierFlags.contains(.option)
        if hasMarkedFiles {
            // Group context menu for marked files
            MultiSelectionContextMenu(
                markedCount: appState.markedCount(for: panelSide),
                panelSide: panelSide,
                isOptionHeld: optionHeld
            ) { action in
                log.debug("[FileRow] multi-selection action=\(action.rawValue) count=\(appState.markedCount(for: panelSide))")
                onMultiSelectionAction(action)
            }
        } else if file.isDirectory {
            DirectoryContextMenu(file: file, panelSide: panelSide, isOptionHeld: optionHeld) { action in
                logContextMenuAction(action, isDirectory: true)
                onDirectoryAction(action, file)
            }
        } else {
            FileContextMenu(file: file, panelSide: panelSide, isOptionHeld: optionHeld) { action in
                logContextMenuAction(action, isDirectory: false)
                onFileAction(action, file)
            }
        }
    }

    // MARK: - Event Handlers
    private func handleSingleClick() {
        let _ = log.debug(#function)
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
        guard let flags = NSApp.currentEvent?.modifierFlags.intersection(.deviceIndependentFlagsMask) else {
            return .none
        }
        let _ = log.debug(#function)
        if flags.contains(.command) { return .command }
        if flags.contains(.shift) { return .shift }
        return .none
    }

    private func handleDoubleClick() {
        log.debug("[FileRow] double-click on '\(file.nameStr)' isDir=\(file.isDirectory)")
        onDoubleClick(file)
    }

    private func handleDropTargeting(_ targeted: Bool) {
        guard isValidDropTarget else { return }
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
        guard isValidDropTarget else {
            log.warning("[FileRow] drop rejected: invalid target")
            return false
        }

        guard !droppedFiles.isEmpty else {
            log.warning("[FileRow] drop rejected: empty payload")
            return false
        }

        let droppedPaths = Set(droppedFiles.map { $0.urlValue.path })
        guard !droppedPaths.contains(file.urlValue.path) else {
            log.warning("[FileRow] drop rejected: self-drop")
            return false
        }

        log.info("[FileRow] drop accepted: \(droppedFiles.count) → '\(file.nameStr)'")
        dragDropManager.prepareTransfer(files: droppedFiles, to: file.urlValue, from: panelSide)
        return true
    }

    // MARK: - Row content — driven by ColumnLayoutModel
    /// Column widths and separators must EXACTLY match TableHeaderView layout:
    ///   [Name flexible] | sep(1pt) | [col2 spec.width] | sep(1pt) | [col3 spec.width] | ...
    /// NO extra padding inside fixed columns — width IS the total width.
    @ViewBuilder
    private var rowContent: some View {
        if isParentEntry {
            parentEntryContent()
        } else {
            normalRowContent()
        }
    }

    // MARK: - Parent entry renderer ("..")
    @ViewBuilder
    private func parentEntryContent() -> some View {
        FileRowView(
            file: file,
            isSelected: isSelected,
            isActivePanel: isActivePanel,
            isMarked: isMarked
        )
        .frame(minWidth: 60, maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
    }

    // MARK: - Normal file row renderer
    @ViewBuilder
    private func normalRowContent() -> some View {
        HStack(alignment: .center, spacing: 0) {
            nameColumnView()

            FileRowMetadataColumnsView(
                file: file,
                layout: layout,
                isParentEntry: isParentEntry,
                colorStore: colorStore
            )
        }
    }

    // MARK: - Name column
    // Uses layout.nameWidth — same value as TableHeaderView nameColumnHeader.
    // This guarantees pixel-perfect alignment between header and rows.
    @ViewBuilder
    private func nameColumnView() -> some View {
        FileRowView(
            file: file,
            isSelected: isSelected,
            isActivePanel: isActivePanel,
            isMarked: isMarked
        )
        .frame(width: layout.nameWidth, alignment: .leading)
        .clipped()
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
    }

    // MARK: - Parent Row View
    private func parentRowView() -> some View {
        rowVisualContent
            .background(parentRowHoverBackground)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: FilePanelStyle.rowHeight)
            .contentShape(Rectangle())
            .onHover(perform: handleParentHover)
            .gesture(rowGestures())
            .animation(.spring(response: 0.35, dampingFraction: 0.70), value: isHoveringParentRow)
            .animation(nil, value: isSelected)
    }

    private var parentRowHoverBackground: Color {
        isHoveringParentRow
            ? Color.accentColor.opacity(0.08)
            : Color.clear
    }

    private func handleParentHover(_ hovering: Bool) {
        withAnimation(.spring(response: 0.30, dampingFraction: 0.75, blendDuration: 0.1)) {
            isHoveringParentRow = hovering
        }

        hovering
            ? NSCursor.pointingHand.set()
            : NSCursor.arrow.set()
    }

    // MARK: - Normal Row View
    private func normalRowView() -> some View {
        rowVisualContent
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: FilePanelStyle.rowHeight)
            .contentShape(Rectangle())
            .gesture(rowGestures())
            .animation(nil, value: isSelected)
            .contextMenu { contextMenuContent }
            .modifier(
                DropTargetModifier(
                    isValidTarget: isValidDropTarget,
                    isDropTargeted: $isDropTargeted,
                    onDrop: handleDrop,
                    onTargetChange: handleDropTargeting
                )
            )
            .task(id: file.id) {
                guard file.isDirectory else { return }
                await runDirectorySizeTask()
            }
    }
}
