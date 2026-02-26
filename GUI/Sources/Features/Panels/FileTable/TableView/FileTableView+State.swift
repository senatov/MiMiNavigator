// FileTableView+State.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 04.02.2026.
// Copyright © 2024-2026 Senatov. All rights reserved.
// Description: State management for FileTableView (sorting, auto-fit)

import SwiftUI

// MARK: - State Management
extension FileTableView {

    func recomputeSortedCache() {
        cachedSortedFiles = files.sorted(by: sorter.compare)
        log.debug("\(#function) panel=\(panelSide) sorted \(cachedSortedFiles.count) by \(sortKey) asc=\(sortAscending)")
    }

    // MARK: - Auto-fit helpers (still available for future use)
    private func autoFitWidth(texts: [String], font: NSFont) -> CGFloat {
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let charW = ("W" as NSString).size(withAttributes: attrs).width
        var maxW: CGFloat = 0
        for text in texts {
            let w = (text as NSString).size(withAttributes: attrs).width
            if w > maxW { maxW = w }
        }
        return ceil(maxW + charW)
    }

    func autoFitSize() -> CGFloat {
        autoFitWidth(texts: cachedSortedFiles.map { $0.fileSizeFormatted },
                     font: .systemFont(ofSize: 12)) + 8
    }

    func autoFitDate() -> CGFloat {
        autoFitWidth(texts: cachedSortedFiles.map { $0.modifiedDateFormatted },
                     font: .systemFont(ofSize: 12)) + 12
    }

    func autoFitPermissions() -> CGFloat {
        autoFitWidth(texts: cachedSortedFiles.map { $0.permissionsFormatted },
                     font: .monospacedSystemFont(ofSize: 11, weight: .regular)) + 12
    }

    func autoFitOwner() -> CGFloat {
        autoFitWidth(texts: cachedSortedFiles.map { $0.ownerFormatted },
                     font: .systemFont(ofSize: 12)) + 12
    }

    func autoFitKind() -> CGFloat {
        autoFitWidth(texts: cachedSortedFiles.map { $0.kindFormatted },
                     font: .systemFont(ofSize: 12)) + 12
    }

    func autoFitChildCount() -> CGFloat {
        autoFitWidth(texts: cachedSortedFiles.map { $0.childCountFormatted },
                     font: .systemFont(ofSize: 12)) + 12
    }
}
