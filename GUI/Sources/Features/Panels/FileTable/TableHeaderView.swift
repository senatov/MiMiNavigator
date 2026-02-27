// TableHeaderView.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 27.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Sortable, resizable column headers. Right-click → context menu to toggle columns.
//
// Layout logic:
//   [Name flexible] | divider | [col2 fixed] | divider | [col3 fixed] | ...
//   Each ResizableDivider controls the width of the column AFTER it.

import FileModelKit
import SwiftUI

// MARK: - Table Header View
struct TableHeaderView: View {
    @Environment(AppState.self) var appState
    let panelSide: PanelSide
    @Bindable var layout: ColumnLayoutModel

    private var sortKey: SortKeysEnum { appState.sortKey }
    private var sortAscending: Bool { appState.bSortAscending }

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
        .shadow(color: Color.black.opacity(0.18), radius: 3, x: 0, y: 2)
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
        .highPriorityGesture(TapGesture().onEnded { toggleSort(.name) })
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
        .highPriorityGesture(TapGesture().onEnded { toggleSort(spec.id) })
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
        HStack(spacing: 0) {
            Text(title)
                .font(
                    .system(
                        size: 13,
                        weight: isActive ? TableHeaderStyle.sortActiveWeight : .regular
                    )
                )
                .foregroundStyle(
                    isActive
                        ? Color(
                            nsColor: NSColor(
                                calibratedRed: 0.1,
                                green: 0.2,
                                blue: 0.7,
                                alpha: 1.0))
                        : TableHeaderStyle.color
                )
                .padding(.leading, 2)
                .lineLimit(1)
            Spacer(minLength: 0)
            if sortKey != nil {
                let iconName =
                    isActive
                    ? (ascending ? "chevron.up" : "chevron.down")
                    : "chevron.up.chevron.down"
                let iconColor: Color = {
                    guard isActive else {
                        return TableHeaderStyle.color.opacity(0.35)
                    }
                    return ascending
                        ? Color(#colorLiteral(red: 0.2196078449, green: 0.007843137719, blue: 0.8549019694, alpha: 1))
                        : Color(#colorLiteral(red: 0.1019607857, green: 0.2784313858, blue: 0.400000006, alpha: 1))
                }()
                Image(systemName: iconName)
                    .font(.system(size: isActive ? 14 : 13, weight: .medium))
                    .foregroundStyle(iconColor)
                    .padding(.trailing, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color.clear)
    }
}
