// TableFileSorter.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 27.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Local file sorting comparator for FileTableView.

import FileModelKit

// MARK: - Table File Sorter
struct TableFileSorter {
    let sortKey: SortKeysEnum
    let ascending: Bool

    // MARK: - Compare
    func compare(_ a: CustomFile, _ b: CustomFile) -> Bool {
        FileSortingService.comesBefore(a, b, by: sortKey, ascending: ascending)
    }
}
