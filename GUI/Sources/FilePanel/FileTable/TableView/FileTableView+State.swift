// FileTableView+State.swift
// MiMiNavigator
//
// Created by Claude AI on 04.02.2026.
// Copyright © 2024-2026 Senatov. All rights reserved.
// Description: State management for FileTableView (columns, sorting)

import SwiftUI

// MARK: - State Management
extension FileTableView {
    
    func loadColumnWidths() {
        log.debug("\(#function) panel=\(panelSide)")
        let widths = columnStorage.load()
        sizeColumnWidth = widths.size
        dateColumnWidth = widths.date
        typeColumnWidth = widths.type
        permissionsColumnWidth = widths.permissions
        ownerColumnWidth = widths.owner
    }
    
    func saveColumnWidths() {
        log.debug("\(#function) panel=\(panelSide)")
        columnStorage.save(
            size: sizeColumnWidth,
            date: dateColumnWidth,
            type: typeColumnWidth,
            permissions: permissionsColumnWidth,
            owner: ownerColumnWidth
        )
    }
    
    func recomputeSortedCache() {
        cachedSortedFiles = files.sorted(by: sorter.compare)
        log.debug("\(#function) panel=\(panelSide) sorted \(cachedSortedFiles.count) files by \(sortKey) asc=\(sortAscending)")
    }
}
