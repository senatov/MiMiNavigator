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
    @Binding var permissionsColumnWidth: CGFloat
    @Binding var ownerColumnWidth: CGFloat
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
                width: $permissionsColumnWidth,
                min: TableColumnConstraints.permissionsMin,
                max: TableColumnConstraints.permissionsMax,
                onEnd: onSave
            )
            
            permissionsHeader
                .frame(width: permissionsColumnWidth, alignment: .leading)
                .padding(.horizontal, 4)
            
            ResizableDivider(
                width: $ownerColumnWidth,
                min: TableColumnConstraints.ownerMin,
                max: TableColumnConstraints.ownerMax,
                onEnd: onSave
            )
            
            ownerHeader
                .frame(width: ownerColumnWidth, alignment: .leading)
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
    
    // MARK: - Permissions Column
    private var permissionsHeader: some View {
        SortableHeader(title: "Perms", sortKey: .permissions, currentKey: sortKey, ascending: sortAscending)
            .contentShape(Rectangle())
            .onTapGesture { toggleSort(.permissions) }
    }
    
    // MARK: - Owner Column
    private var ownerHeader: some View {
        SortableHeader(title: "Owner", sortKey: .owner, currentKey: sortKey, ascending: sortAscending)
            .contentShape(Rectangle())
            .onTapGesture { toggleSort(.owner) }
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
    
    // MARK: - Styling (Finder-style: subtle gray)
    private var headerBackground: some View {
        Color(nsColor: .windowBackgroundColor)
    }
    
    private var bottomBorder: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor))
            .frame(height: 1)
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
