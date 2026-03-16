// AppState+Sorting.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 15.03.2026.
// Copyright © 2025-2026 Senatov. All rights reserved.
// Description: Sort key management and file list re-sorting

import FileModelKit
import Foundation

// MARK: - Sorting
extension AppState {

    func updateSorting(key: SortKeysEnum? = nil, ascending: Bool? = nil) {
        if let key { sortKey = key }
        if let ascending { bSortAscending = ascending }
        MiMiDefaults.shared.set(sortKey.rawValue, forKey: "MiMiNavigator.sortKey")
        MiMiDefaults.shared.set(bSortAscending, forKey: "MiMiNavigator.sortAscending")
        displayedLeftFiles = FileSortingService.sort(displayedLeftFiles, by: sortKey, bDirection: bSortAscending)
        displayedRightFiles = FileSortingService.sort(displayedRightFiles, by: sortKey, bDirection: bSortAscending)
    }

    func applySorting(_ items: [CustomFile]) -> [CustomFile] {
        FileSortingService.sort(items, by: sortKey, bDirection: bSortAscending)
    }
}
