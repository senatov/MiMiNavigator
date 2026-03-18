// TableHeaderView.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 27.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Sortable, resizable, draggable column headers.
//              Right-click → context menu to toggle columns.
//
// Interaction model:
//   - Click sort arrow icon → toggle sort direction
//   - Double-click column title area → auto-fit column width to content
//   - Drag divider between columns → resize
//   - Drag column header → reorder (Name always pinned at index 0)
//
// Layout logic (must exactly mirror FileRow/FileRowMetadataColumnsView):
//   [Name flex + pad(4)] | ResizableDivider(1pt) | [col2 frame(spec.width) + pad(cellPadding)] | ...
//
// Sub-components (separate files):
//   SortableHeader.swift  — individual column header (title + sort arrow)
//   SortArrowButton.swift — clickable Finder-style sort triangle

import FileModelKit
import SwiftUI

// MARK: - TableHeaderView
struct TableHeaderView: View {
    @Environment(AppState.self) var appState
    let panelSide: PanelSide
    @Bindable var layout: ColumnLayoutModel
    var isFocused: Bool = false

    /// Column ID currently being dragged (for drop highlight)
    @State private var dragOverTargetID: ColumnID? = nil

    private var sortKey: SortKeysEnum { appState.sortKey }
    private var sortAscending: Bool { appState.bSortAscending }

    /// Header background color - warmWhite when focused
    private var headerBackgroundColor: Color {
        if isFocused {
            return ColorThemeStore.shared.activeTheme.warmWhite
        } else {
            return TableHeaderStyle.backgroundColor
        }
    }

    var body: some View {
        let fixedCols = layout.visibleColumns.filter { $0.id != .name }
        return HStack(alignment: .center, spacing: 0) {
            nameHeader
            ForEach(fixedCols.indices, id: \.self) { i in
                let spec = fixedCols[i]
                ResizableDivider(
                    width: Binding(
                        get: { spec.width },
                        set: { layout.setWidth($0, for: spec.id) }
                    ),
                    min: spec.id.minDragWidth,
                    max: TableColumnDefaults.maxWidth,
                    onEnd: { layout.saveWidths() }
                )
                draggableColumnHeader(for: spec)
            }
        }
        // NO .padding(.horizontal) here — name column carries its own 4pt padding
        // to match FileRow.nameColumnView which also uses .padding(.horizontal, 4).
        // Fixed columns get their spacing from cellPadding inside the frame.
        .frame(height: 22)
        .padding(.vertical, 1)
        .background(headerBackgroundColor)
        .overlay {
            // thin dark-navy border around the whole header — crisp, no blur
            RoundedRectangle(cornerRadius: 3)
                .stroke(
                    Color(nsColor: NSColor(calibratedRed: 0.08, green: 0.13, blue: 0.32, alpha: 0.50)),
                    lineWidth: 0.75
                )
                .allowsHitTesting(false)
        }
        .shadow(color: Color.black.opacity(0.10), radius: 1, x: 0, y: 1)
        .contextMenu { columnToggleMenu }
    }

    // MARK: - Name Column (flexible)
    // padding(.horizontal, 4) mirrors FileRow.nameColumnView padding — keeps name col aligned.
    private var nameHeader: some View {
        SortableHeader(
            title: ColumnID.name.title,
            icon: ColumnID.name.icon,
            sortKey: ColumnID.name.sortKey,
            currentKey: sortKey,
            ascending: sortAscending,
            onSort: { toggleSort(.name) },
            onAutoFit: nil
        )
        .frame(minWidth: 60, maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
        .clipped()
    }

    // MARK: - Draggable Column Header
    private func draggableColumnHeader(for spec: ColumnSpec) -> some View {
        SortableHeader(
            title: spec.id.title,
            icon: spec.id.icon,
            sortKey: spec.id.sortKey,
            currentKey: sortKey,
            ascending: sortAscending,
            onSort: { toggleSort(spec.id) },
            onAutoFit: {
                autoFitColumn(spec.id)
            }
        )
        .padding(.horizontal, TableColumnDefaults.cellPadding)
        .frame(width: spec.width, alignment: spec.id.alignment)
        .background(
            dragOverTargetID == spec.id
                ? Color.accentColor.opacity(0.15)
                : Color.clear
        )
        .overlay(alignment: .leading) {
            if dragOverTargetID == spec.id {
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: 2)
            }
        }
        .draggable(spec.id) {
            Text(spec.id.title)
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 4))
        }
        .dropDestination(for: ColumnID.self) { droppedItems, _ in
            guard let sourceID = droppedItems.first else { return false }
            layout.moveColumn(sourceID, before: spec.id)
            dragOverTargetID = nil
            return true
        } isTargeted: { targeted in
            dragOverTargetID = targeted ? spec.id : nil
        }
    }

    // MARK: - Context Menu (right-click on header)
    @ViewBuilder
    private var columnToggleMenu: some View {
        ForEach(layout.columns) { spec in
            let col = spec.id
            if !col.isRequired {
                Button {
                    layout.toggle(col)
                } label: {
                    Label(col.title, systemImage: spec.isVisible ? "checkmark" : "")
                }
            }
        }
        Divider()
        Button("Restore Defaults") { restoreDefaults() }
    }

    // MARK: - Sort Toggle
    private func toggleSort(_ col: ColumnID) {
        guard let key = col.sortKey else { return }
        appState.focusedPanel = panelSide
        if sortKey == key {
            appState.bSortAscending.toggle()
        } else {
            appState.sortKey = key
            appState.bSortAscending = true
        }
        log.debug("[Sort] toggleSort panel=\(panelSide) key=\(appState.sortKey) asc=\(appState.bSortAscending)")
        appState.updateSorting()
    }

    // MARK: - Auto-fit Column Width
    private func autoFitColumn(_ col: ColumnID) {
        let files = panelSide == .left ? appState.displayedLeftFiles : appState.displayedRightFiles
        guard !files.isEmpty else { return }
        let texts: [String]
        let font: NSFont
        switch col {
            case .size:
                texts = files.map { $0.fileSizeFormatted }
                font = .systemFont(ofSize: 12)
            case .dateModified:
                texts = files.map { $0.modifiedDateFormatted }
                font = .systemFont(ofSize: 12)
            case .kind:
                texts = files.map { $0.kindFormatted }
                font = .systemFont(ofSize: 12)
            case .permissions:
                texts = files.map { $0.permissionsFormatted }
                font = .monospacedSystemFont(ofSize: 11, weight: .regular)
            case .owner:
                texts = files.map { $0.ownerFormatted }
                font = .systemFont(ofSize: 12)
            case .childCount:
                texts = files.map { $0.childCountFormatted }
                font = .systemFont(ofSize: 12)
            case .dateCreated:
                texts = files.map { $0.creationDateFormatted }
                font = .systemFont(ofSize: 12)
            case .dateLastOpened:
                texts = files.map { $0.lastOpenedFormatted }
                font = .systemFont(ofSize: 12)
            case .dateAdded:
                texts = files.map { $0.dateAddedFormatted }
                font = .systemFont(ofSize: 12)
            case .group:
                texts = files.map { $0.groupNameFormatted }
                font = .systemFont(ofSize: 12)
            case .name:
                return
        }
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        var maxW: CGFloat = 0
        for text in texts {
            let w = (text as NSString).size(withAttributes: attrs).width
            if w > maxW { maxW = w }
        }
        let optimal = ceil(maxW + 2 * TableColumnDefaults.cellPadding)
        let clamped = Swift.min(Swift.max(optimal, col.minHeaderWidth), TableColumnDefaults.maxWidth)
        layout.setWidth(clamped, for: col)
        layout.saveWidths()
        log.debug("[AutoFit] col=\(col) optimal=\(Int(clamped))pt")
    }

    // MARK: - Restore Defaults
    private func restoreDefaults() {
        for col in ColumnID.allCases {
            if let idx = layout.columns.firstIndex(where: { $0.id == col }) {
                layout.columns[idx].isVisible = col.defaultVisible
                layout.columns[idx].width = col.defaultWidth
            }
        }
        layout.saveWidths()
    }
}
