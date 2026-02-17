// FileTableView+State.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 04.02.2026.
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

    // MARK: - Auto-fit: compute optimal column width from content

    /// Measure pixel width of the longest string in column + 1 char padding
    private func autoFitWidth(texts: [String], font: NSFont) -> CGFloat {
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let charW = ("W" as NSString).size(withAttributes: attrs).width
        var maxW: CGFloat = 0
        for text in texts {
            let w = (text as NSString).size(withAttributes: attrs).width
            if w > maxW { maxW = w }
        }
        return ceil(maxW + charW)  // +1 character
    }

    func autoFitSize() -> CGFloat {
        autoFitWidth(
            texts: cachedSortedFiles.map { $0.fileSizeFormatted },
            font: NSFont.systemFont(ofSize: 12)
        ) + 8  // account for padding(.trailing, 8)
    }

    func autoFitDate() -> CGFloat {
        autoFitWidth(
            texts: cachedSortedFiles.map { $0.modifiedDateFormatted },
            font: NSFont.systemFont(ofSize: 12)
        ) + 12  // account for padding(.horizontal, 6)
    }

    func autoFitPermissions() -> CGFloat {
        autoFitWidth(
            texts: cachedSortedFiles.map { $0.permissionsFormatted },
            font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        ) + 12
    }

    func autoFitOwner() -> CGFloat {
        autoFitWidth(
            texts: cachedSortedFiles.map { $0.ownerFormatted },
            font: NSFont.systemFont(ofSize: 12)
        ) + 12
    }

    func autoFitType() -> CGFloat {
        autoFitWidth(
            texts: cachedSortedFiles.map { $0.fileTypeDisplay },
            font: NSFont.systemFont(ofSize: 12)
        ) + 12
    }
}
