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
    let panelSide: PanelSide
    let layout: ColumnLayoutModel
    let layoutVersion: Int
    let onSelect: (CustomFile) -> Void
    let onDoubleClick: (CustomFile) -> Void
    let onFileAction: (FileAction, CustomFile) -> Void
    let onDirectoryAction: (DirectoryAction, CustomFile) -> Void
    let onMultiSelectionAction: (MultiSelectionAction) -> Void

    @Environment(AppState.self) var appState
    @Environment(DragDropManager.self) var dragDropManager
    @Environment(\.displayScale) private var displayScale

    @State private var colorStore = ColorThemeStore.shared
    @State private var isDropTargeted: Bool = false
    @State private var isHoveringParentRow: Bool = false
    @State private var isHoveringRow: Bool = false

    // MARK: - Selection colors — live from ColorThemeStore
    private var selectionActiveFill: Color { colorStore.activeTheme.selectionActive }
    private var selectionInactiveFill: Color { colorStore.activeTheme.selectionInactive }

    private static let dropTargetFill = Color.accentColor.opacity(0.2)
    private static let dropTargetBorder = Color.accentColor

    private var onePixel: CGFloat { 1.0 / displayScale }

    private func selectionBorderOverlay(color: Color) -> some View {
        ZStack {
            Rectangle().fill(color)
                .frame(height: onePixel)
                .frame(maxHeight: .infinity, alignment: .top)
            Rectangle().fill(color)
                .frame(height: onePixel)
                .frame(maxHeight: .infinity, alignment: .bottom)
            Rectangle().fill(color)
                .frame(width: onePixel)
                .frame(maxWidth: .infinity, alignment: .leading)
            Rectangle().fill(color)
                .frame(width: onePixel)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

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
            .zIndex(isSelected ? 1 : 0)  // selected row renders above neighbours — border fully visible
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

    private var stableContent: some View {
        ZStack(alignment: .leading) {
            zebraBackground
            highlightLayer
            rowContent
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
        if isParentEntry {
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

    @ViewBuilder
    private var highlightLayer: some View {
        if isDropTargetActive {
            dropTargetHighlight
        } else if isSelected || isHoveringRow {
            selectionHighlight
        }
    }

    private var isDropTargetActive: Bool {
        isDropTargeted && isValidDropTarget
    }

    private var dropTargetHighlight: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(Self.dropTargetFill)
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Self.dropTargetBorder, lineWidth: 2)
            )
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(false)
    }

    private var selectionHighlight: some View {
        let base = isActivePanel ? selectionActiveFill : selectionInactiveFill
        let fill = isSelected ? base : base.opacity(0.6)

        return RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(fill)
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    // Draw the border strictly inside the row bounds to avoid clipping on the last visible row.
                    .inset(by: onePixel * 0.5)
                    .strokeBorder(selectionBorderColor, lineWidth: onePixel)
            )
            .padding(.horizontal, 3)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(false)
    }

    private var selectionBorderColor: Color {
        Color(#colorLiteral(red: 0.1215686277, green: 0.01176470611, blue: 0.4235294163, alpha: 1))
            .opacity(isActivePanel ? 0.75 : 0.35)
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
        guard let flags = NSApp.currentEvent?.modifierFlags.intersection(.deviceIndependentFlagsMask) else {
            return .none
        }
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
        stableContent
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: FilePanelStyle.rowHeight)
            .contentShape(Rectangle())
            .onHover(perform: handleParentHover)
            .gesture(rowGestures())
            .animation(.spring(response: 0.35, dampingFraction: 0.70), value: isHoveringParentRow)
            .animation(nil, value: isSelected)
    }

    private func handleParentHover(_ hovering: Bool) {
        withAnimation(.spring(response: 0.30, dampingFraction: 0.75, blendDuration: 0.1)) {
            isHoveringParentRow = hovering
            isHoveringRow = hovering
        }

        hovering
            ? NSCursor.pointingHand.set()
            : NSCursor.arrow.set()
    }

    // MARK: - Normal Row View
    private func normalRowView() -> some View {
        stableContent
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: FilePanelStyle.rowHeight)
            .contentShape(Rectangle())
            .gesture(rowGestures())
            .onHover { hovering in
                isHoveringRow = hovering
            }
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
