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
    }
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
    @State private var isHoveringParentRow: Bool = false

    // MARK: - Selection colors — live from ColorThemeStore
    private var selectionActiveFill: Color { colorStore.activeTheme.selectionActive }
    private var selectionInactiveFill: Color { colorStore.activeTheme.selectionInactive }

    private static let dropTargetFill = Color.accentColor.opacity(0.2)
    private static let dropTargetBorder = Color.accentColor

    private var isActivePanel: Bool {
        appState.focusedPanel == panelSide
    }

    var isParentEntry: Bool {
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
            .zIndex(isSelected ? 1 : 0)  // selected row renders above neighbours — border fully visible
    }

    // MARK: - Main Container
    private var rowContainer: some View {
        Group {
            if isParentEntry {
                // ".." entry — behaves like a single interactive element (arrow + "..")
                stableContent
                    .background(
                        isHoveringParentRow
                            ? Color.accentColor.opacity(0.08)
                            : Color.clear
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: FilePanelStyle.rowHeight)
                    .contentShape(Rectangle())
                    .onHover { hovering in
                        withAnimation(.spring(response: 0.30, dampingFraction: 0.75, blendDuration: 0.1)) {
                            isHoveringParentRow = hovering
                        }

                        if hovering {
                            NSCursor.pointingHand.set()
                        } else {
                            NSCursor.arrow.set()
                        }
                    }
                    .simultaneousGesture(doubleTapGesture)
                    .simultaneousGesture(singleTapGesture)
                    .animation(.spring(response: 0.35, dampingFraction: 0.70), value: isHoveringParentRow)
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
                    // Drag is handled by DragOverlayView (AppKit NSDraggingSession)
                    // which supports true multi-file drag. SwiftUI .onDrag only
                    // supports one NSItemProvider = one file.
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
    @ViewBuilder
    private var zebraBackground: some View {
        if isParentEntry {
            // ".." row — fixed light grey background regardless of zebra index
            Color(nsColor: .systemGray)
                .opacity(0.13)
                .allowsHitTesting(false)
        } else {
            let isOdd = index % 2 == 1
            if isActivePanel {
                // Active panel: themed zebra (aged-paper by default)
                (isOdd ? DesignTokens.zebraActiveOdd : DesignTokens.zebraActiveEven)
                    .allowsHitTesting(false)
            } else {
                // Inactive panel: themed zebra (near-white by default)
                (isOdd ? DesignTokens.zebraInactiveOdd : DesignTokens.zebraInactiveEven)
                    .allowsHitTesting(false)
            }
        }
    }

    @ViewBuilder
    private var highlightLayer: some View {
        if isDropTargeted && isValidDropTarget {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Self.dropTargetFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Self.dropTargetBorder, lineWidth: 2)
                )
                .padding(.horizontal, 4)
                .allowsHitTesting(false)
        } else if isSelected {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isActivePanel ? selectionActiveFill : selectionInactiveFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .inset(by: 0.5)
                        .strokeBorder(
                            Color(#colorLiteral(red: 0.18, green: 0.44, blue: 0.85, alpha: 1)).opacity(isActivePanel ? 0.75 : 0.35),
                            lineWidth: 1)
                )
                .padding(.horizontal, 3)
                .padding(.vertical, 0)
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
        if file.isHidden { return colorStore.activeTheme.hiddenFileColor }
        return col.columnColor(from: colorStore.activeTheme)
    }

    // MARK: - System font (Finder style)
    private var columnFont: Font {
        .system(size: 12)
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
        let fixedCols = layout.visibleColumns.filter { $0.id != .name }

        HStack(alignment: .center, spacing: 0) {
            nameColumnView()

            ForEach(fixedCols.indices, id: \.self) { i in
                let spec = fixedCols[i]
                ColumnSeparator()
                metadataCell(for: spec)
            }
        }
    }

    // MARK: - Name column (flexible)
    @ViewBuilder
    private func nameColumnView() -> some View {
        FileRowView(
            file: file,
            isSelected: isSelected,
            isActivePanel: isActivePanel,
            isMarked: isMarked
        )
        .frame(minWidth: 60, maxWidth: .infinity, alignment: .leading)
        .layoutPriority(0)  // metadata columns must win width conflicts
        .clipped()
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
    }

    // MARK: - Metadata column cell helper
    @ViewBuilder
    private func metadataCell(for spec: ColumnSpec) -> some View {
        cellTextForMetadataColumn(spec.id)
            .font(metadataFont(for: spec.id))
            .foregroundStyle(cellColor(for: spec.id))
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.leading, spec.id == .owner ? TableColumnDefaults.cellPadding + 1 : TableColumnDefaults.cellPadding)
            .padding(.trailing, TableColumnDefaults.cellPadding)
            .frame(
                width: clampedColumnWidth(spec.width),
                alignment: spec.id.alignment
            )
    }

    // MARK: - Column rendering helpers
    private func metadataFont(for col: ColumnID) -> Font {
        if col == .permissions {
            return .system(size: 11, design: .monospaced)
        }

        if col == .size || col == .childCount || isDateColumn(col) {
            return columnFont.monospacedDigit()
        }

        return columnFont
    }

    private func isDateColumn(_ col: ColumnID) -> Bool {
        switch col {
            case .dateModified, .dateCreated, .dateLastOpened, .dateAdded:
                return true
            default:
                return false
        }
    }

    private func clampedColumnWidth(_ width: CGFloat) -> CGFloat {
        // Minimum width ≈ 3 characters (roughly 24 px in 12pt system font)
        let minWidth: CGFloat = 24

        // Maximum allowed width (design constraint)
        let maxWidth: CGFloat = 456  // 450 + ~6px visual padding

        return min(max(width, minWidth), maxWidth)
    }

    @ViewBuilder
    private func cellTextForMetadataColumn(_ col: ColumnID) -> some View {
        // Name column is rendered separately in `nameColumnView()`.
        if col == .name {
            EmptyView()
        } else {
            cellText(for: col)
        }
    }

    @ViewBuilder
    private func cellText(for col: ColumnID) -> some View {
        switch col {
            case .dateModified:
                Text(file.modifiedDateFormatted)
            case .size:
                sizeColumnView()
            case .kind:
                KindCell(file: file)
            case .permissions:
                PermissionsCell(permissions: file.permissionsFormatted)
            case .owner:
                Text(file.ownerFormatted)
            case .childCount:
                Text(file.childCountFormatted)
            case .dateCreated:
                Text(file.creationDateFormatted)
            case .dateLastOpened:
                Text(file.lastOpenedFormatted)
            case .dateAdded:
                Text(file.dateAddedFormatted)
            case .group:
                Text(file.groupNameFormatted)
            case .name:
                // Kept for exhaustiveness; should never be hit.
                EmptyView()
        }
    }

}
