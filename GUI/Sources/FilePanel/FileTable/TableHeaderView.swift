// TableHeaderView.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 27.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Sortable and resizable column headers for FileTableView

import SwiftUI

// MARK: - Table Header View
/// Displays sortable column headers with resizable dividers
struct TableHeaderView: View {
    @Environment(AppState.self) var appState
    
    let panelSide: PanelSide
    @Binding var sortKey: SortKeysEnum
    @Binding var sortAscending: Bool
    @Binding var sizeColumnWidth: CGFloat
    @Binding var dateColumnWidth: CGFloat
    @Binding var typeColumnWidth: CGFloat
    let onSave: () -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            nameHeader
            
            ResizableDivider(
                width: $sizeColumnWidth,
                min: TableColumnConstraints.sizeMin,
                max: TableColumnConstraints.sizeMax,
                onEnd: onSave
            )
            
            sizeHeader
                .frame(width: sizeColumnWidth, alignment: .trailing)
                .padding(.horizontal, 4)
            
            ResizableDivider(
                width: $dateColumnWidth,
                min: TableColumnConstraints.dateMin,
                max: TableColumnConstraints.dateMax,
                onEnd: onSave
            )
            
            dateHeader
                .frame(width: dateColumnWidth, alignment: .leading)
                .padding(.horizontal, 4)
            
            ResizableDivider(
                width: $typeColumnWidth,
                min: TableColumnConstraints.typeMin,
                max: TableColumnConstraints.typeMax,
                onEnd: onSave
            )
            
            typeHeader
                .frame(width: typeColumnWidth, alignment: .leading)
                .padding(.horizontal, 4)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 4)
        .background(headerBackground)
        .overlay(alignment: .bottom) { bottomBorder }
    }
    
    // MARK: - Name Column
    private var nameHeader: some View {
        SortableHeader(title: "Name", sortKey: .name, currentKey: sortKey, ascending: sortAscending)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { toggleSort(.name) }
    }
    
    // MARK: - Size Column
    private var sizeHeader: some View {
        SortableHeader(title: "Size", sortKey: .size, currentKey: sortKey, ascending: sortAscending)
            .contentShape(Rectangle())
            .onTapGesture { toggleSort(.size) }
    }
    
    // MARK: - Date Column
    private var dateHeader: some View {
        SortableHeader(title: "Date", sortKey: .date, currentKey: sortKey, ascending: sortAscending)
            .contentShape(Rectangle())
            .onTapGesture { toggleSort(.date) }
    }
    
    // MARK: - Type Column
    private var typeHeader: some View {
        SortableHeader(title: "Type", sortKey: .type, currentKey: sortKey, ascending: sortAscending)
            .contentShape(Rectangle())
            .onTapGesture { toggleSort(.type) }
    }
    
    // MARK: - Actions
    private func toggleSort(_ key: SortKeysEnum) {
        appState.focusedPanel = panelSide
        if sortKey == key {
            sortAscending.toggle()
        } else {
            sortKey = key
            sortAscending = true
        }
        appState.updateSorting(key: key, ascending: sortAscending)
        log.debug("[TableHeaderView] sort changed: key=\(key) asc=\(sortAscending)")
    }
    
    // MARK: - Styling
    private var headerBackground: some View {
        LinearGradient(
            colors: [
                Color(nsColor: .systemBlue).opacity(0.06),
                Color(nsColor: .windowBackgroundColor).opacity(0.95)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    private var bottomBorder: some View {
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        return Rectangle()
            .fill(Color.black.opacity(0.2))
            .frame(height: max(1.0 / scale, 1.0))
            .allowsHitTesting(false)
    }
}

// MARK: - Sortable Header
/// Single column header with sort indicator
struct SortableHeader: View {
    let title: String
    let sortKey: SortKeysEnum
    let currentKey: SortKeysEnum
    let ascending: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .font(TableHeaderStyle.font)
                .foregroundStyle(TableHeaderStyle.color)
            
            if currentKey == sortKey {
                Image(systemName: ascending ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(TableHeaderStyle.color)
            }
        }
    }
}
