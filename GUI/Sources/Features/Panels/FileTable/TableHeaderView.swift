// TableHeaderView.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 27.01.2026.
// Refactored: 20.02.2026 — dynamic columns via ColumnLayoutModel, context menu show/hide
// Copyright © 2026 Senatov. All rights reserved.
// Description: Sortable, resizable column headers. Right-click → context menu to toggle columns.

import SwiftUI

// MARK: - Table Header View
struct TableHeaderView: View {
    @Environment(AppState.self) var appState

    let panelSide: PanelSide
    @Binding var sortKey: SortKeysEnum
    @Binding var sortAscending: Bool
    @Bindable var layout: ColumnLayoutModel

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            ForEach(layout.visibleColumns) { spec in
                columnHeader(for: spec)
            }
        }
        .frame(height: 24)
        .padding(.vertical, 2)
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

    // MARK: - Single Column Header

    @ViewBuilder
    private func columnHeader(for spec: ColumnSpec) -> some View {
        let col = spec.id
        let isName = col == .name

        Group {
            if isName {
                SortableHeader(
                    title: col.title,
                    sortKey: col.sortKey,
                    currentKey: sortKey,
                    ascending: sortAscending
                )
                .frame(minWidth: 60, maxWidth: .infinity, alignment: .leading)
                .clipped()
                .contentShape(Rectangle())
                .onTapGesture { toggleSort(col) }
            } else {
                HStack(spacing: 0) {
                    ResizableDivider(
                        width: Binding(
                            get: { spec.width },
                            set: { layout.setWidth($0, for: col) }
                        ),
                        min: TableColumnDefaults.minWidth,
                        max: TableColumnDefaults.maxWidth,
                        onEnd: { layout.saveWidths() }
                    )

                    SortableHeader(
                        title: col.title,
                        sortKey: col.sortKey,
                        currentKey: sortKey,
                        ascending: sortAscending
                    )
                    .frame(width: spec.width, alignment: col.alignment)
                    .padding(.horizontal, 6)
                    .contentShape(Rectangle())
                    .onTapGesture { toggleSort(col) }
                }
            }
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
                    Label(
                        col.title,
                        systemImage: spec.isVisible ? "checkmark" : ""
                    )
                }
            }
        }
        Divider()
        Button("Restore Defaults") {
            restoreDefaults()
        }
    }

    // MARK: - Sort

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

    // MARK: - Restore defaults

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

// MARK: - Sortable Header (unchanged API, extended to accept optional sortKey)
struct SortableHeader: View {
    let title: String
    let sortKey: SortKeysEnum?         // nil = column is not sortable
    let currentKey: SortKeysEnum
    let ascending: Bool

    private var isActive: Bool {
        guard let sk = sortKey else { return false }
        return currentKey == sk
    }

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .font(TableHeaderStyle.font)
                .foregroundStyle(isActive ? TableHeaderStyle.sortIndicatorColor : TableHeaderStyle.color)

            Image(systemName: sortIcon)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(isActive ? TableHeaderStyle.sortIndicatorColor : Color.secondary.opacity(0.5))
        }
        .background(isActive ? TableHeaderStyle.activeSortBackground : Color.clear)
    }

    private var sortIcon: String {
        guard sortKey != nil else { return "" }
        if isActive { return ascending ? "chevron.up" : "chevron.down" }
        return "chevron.up.chevron.down"
    }
}
