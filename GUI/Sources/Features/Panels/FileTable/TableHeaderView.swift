// TableHeaderView.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 27.01.2026.
// Refactored: 20.02.2026 — dynamic columns via ColumnLayoutModel, context menu show/hide
// Copyright © 2026 Senatov. All rights reserved.
// Description: Sortable, resizable column headers. Right-click → context menu to toggle columns.
//
// Layout logic:
//   [Name flexible] | divider | [col2 fixed] | divider | [col3 fixed] | ...
//   Each ResizableDivider controls the width of the column AFTER it.

import SwiftUI

// MARK: - Table Header View
struct TableHeaderView: View {
    @Environment(AppState.self) var appState

    let panelSide: PanelSide
    @Binding var sortKey: SortKeysEnum
    @Binding var sortAscending: Bool
    @Bindable var layout: ColumnLayoutModel

    var body: some View {
        let fixedCols = layout.visibleColumns.filter { $0.id != .name }

        return HStack(alignment: .center, spacing: 0) {
            // Name — flexible, always first
            nameHeader

            // Fixed columns — separator before each, using indices for reliable rendering
            ForEach(fixedCols.indices, id: \.self) { i in
                let spec = fixedCols[i]
                ResizableDivider(
                    width: Binding(
                        get: { spec.width },
                        set: { layout.setWidth($0, for: spec.id) }
                    ),
                    min: TableColumnDefaults.minWidth,
                    max: TableColumnDefaults.maxWidth,
                    onEnd: { layout.saveWidths() }
                )
                fixedColumnHeader(for: spec)
            }
        }
        .frame(height: 22)
        .padding(.vertical, 1)
        .padding(.horizontal, 4)
        .background(TableHeaderStyle.backgroundColor)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(TableHeaderStyle.separatorColor)
                .frame(height: 1)
                .allowsHitTesting(false)
        }
        .contextMenu { columnToggleMenu }
    }

    // MARK: - Name Column (flexible)
    private var nameHeader: some View {
        SortableHeader(
            title: ColumnID.name.title,
            sortKey: ColumnID.name.sortKey,
            currentKey: sortKey,
            ascending: sortAscending
        )
        .frame(minWidth: 60, maxWidth: .infinity, alignment: .leading)
        .clipped()
        .contentShape(Rectangle())
        .onTapGesture { toggleSort(.name) }
    }

    // MARK: - Fixed Column Header
    private func fixedColumnHeader(for spec: ColumnSpec) -> some View {
        SortableHeader(
            title: spec.id.title,
            sortKey: spec.id.sortKey,
            currentKey: sortKey,
            ascending: sortAscending
        )
        .frame(width: spec.width, alignment: spec.id.alignment)
        .padding(.horizontal, TableColumnDefaults.cellPadding)
        .contentShape(Rectangle())
        .onTapGesture { toggleSort(spec.id) }
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
            sortAscending.toggle()
        } else {
            sortKey = key
            sortAscending = true
        }
        appState.updateSorting(key: key, ascending: sortAscending)
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

// MARK: - Sortable Header
struct SortableHeader: View {
    let title: String
    let sortKey: SortKeysEnum?
    let currentKey: SortKeysEnum
    let ascending: Bool

    private var isActive: Bool {
        guard let sk = sortKey else { return false }
        return currentKey == sk
    }

    var body: some View {
        HStack(spacing: 3) {
            Text(title)
                .font(isActive
                    ? TableHeaderStyle.font.weight(TableHeaderStyle.sortActiveWeight)
                    : TableHeaderStyle.font)
                .foregroundStyle(isActive ? TableHeaderStyle.sortIndicatorColor : TableHeaderStyle.color)
                .lineLimit(1)

            if sortKey != nil {
                Image(systemName: isActive ? (ascending ? "chevron.up" : "chevron.down") : "chevron.up.chevron.down")
                    .font(.system(size: isActive ? 11 : 10, weight: isActive ? .semibold : .regular))
                    .foregroundStyle(isActive ? TableHeaderStyle.sortIndicatorColor : Color.black.opacity(0.75))
            }
        }
        .background(isActive ? TableHeaderStyle.activeSortBackground : Color.clear)
    }
}
