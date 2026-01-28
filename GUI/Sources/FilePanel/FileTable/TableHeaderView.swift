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
            
            headerDivider
            sizeHeader
            
            headerDivider
            dateHeader
            
            headerDivider
            permissionsHeader
            
            headerDivider
            ownerHeader
            
            headerDivider
            typeHeader
        }
        .frame(height: 24)
        .padding(.horizontal, 4)
        .background(TableHeaderStyle.backgroundColor)
        .overlay(alignment: .bottom) { bottomBorder }
    }
    
    // MARK: - Header Divider
    private var headerDivider: some View {
        Rectangle()
            .fill(TableHeaderStyle.separatorColor)
            .frame(width: 1)
            .padding(.vertical, 4)
            .allowsHitTesting(false)
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
            .frame(width: sizeColumnWidth, alignment: .trailing)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
            .onTapGesture { toggleSort(.size) }
    }
    
    // MARK: - Date Column
    private var dateHeader: some View {
        SortableHeader(title: "Date", sortKey: .date, currentKey: sortKey, ascending: sortAscending)
            .frame(width: dateColumnWidth, alignment: .leading)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
            .onTapGesture { toggleSort(.date) }
    }
    
    // MARK: - Type Column
    private var typeHeader: some View {
        SortableHeader(title: "Type", sortKey: .type, currentKey: sortKey, ascending: sortAscending)
            .frame(width: typeColumnWidth, alignment: .leading)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
            .onTapGesture { toggleSort(.type) }
    }
    
    // MARK: - Permissions Column
    private var permissionsHeader: some View {
        SortableHeader(title: "Perms", sortKey: .permissions, currentKey: sortKey, ascending: sortAscending)
            .frame(width: permissionsColumnWidth, alignment: .leading)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
            .onTapGesture { toggleSort(.permissions) }
    }
    
    // MARK: - Owner Column
    private var ownerHeader: some View {
        SortableHeader(title: "Owner", sortKey: .owner, currentKey: sortKey, ascending: sortAscending)
            .frame(width: ownerColumnWidth, alignment: .leading)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
            .onTapGesture { toggleSort(.owner) }
    }
    
    // MARK: - Actions
    private func toggleSort(_ key: SortKeysEnum) {
        let oldKey = sortKey
        let oldAsc = sortAscending
        
        appState.focusedPanel = panelSide
        if sortKey == key {
            sortAscending.toggle()
        } else {
            sortKey = key
            sortAscending = true
        }
        appState.updateSorting(key: key, ascending: sortAscending)
        log.info("[TableHeader] sort changed: panel=\(panelSide) oldKey=\(oldKey) oldAsc=\(oldAsc) → newKey=\(sortKey) newAsc=\(sortAscending)")
    }
    
    // MARK: - Styling
    private var bottomBorder: some View {
        Rectangle()
            .fill(TableHeaderStyle.separatorColor)
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
    
    private var isActive: Bool { currentKey == sortKey }
    
    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .font(TableHeaderStyle.font)
                .foregroundStyle(isActive ? TableHeaderStyle.sortIndicatorColor : TableHeaderStyle.color)
            
            // Always show sort indicator, active column highlighted
            Image(systemName: sortIcon)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(isActive ? TableHeaderStyle.sortIndicatorColor : Color.secondary.opacity(0.5))
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .background(
            isActive
                ? TableHeaderStyle.sortIndicatorColor.opacity(0.1)
                : Color.clear
        )
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
    
    private var sortIcon: String {
        if isActive {
            return ascending ? "chevron.up" : "chevron.down"
        }
        return "chevron.up.chevron.down"
    }
}
