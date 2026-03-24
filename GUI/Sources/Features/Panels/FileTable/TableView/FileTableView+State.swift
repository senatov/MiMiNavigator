// FileTableView+State.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 04.02.2026.
// Copyright © 2024-2026 Senatov. All rights reserved.
// Description: State management for FileTableView (sorting, auto-fit)

import FileModelKit
import SwiftUI

// MARK: - State Management
extension FileTableView {

    /// Track last files reference to skip redundant rebuilds
    private static var lastFilesHash: [FavPanelSide: Int] = [:]

    func recomputeSortedCache() {
        /// Very cheap change detection: count + first + last file hash.
        /// Avoids rebuilding rows for large directories when the array is unchanged.
        let firstHash = files.isEmpty ? 0 : files[0].id.hashValue
        let lastHash = files.isEmpty ? 0 : files[files.count - 1].id.hashValue
        let newHash = files.count ^ firstHash ^ lastHash
        if Self.lastFilesHash[panelSide] == newHash && cachedSortedFiles.count == files.count {
            return
        }
        Self.lastFilesHash[panelSide] = newHash

        cachedSortedFiles = files
        rebuildIndexByID()
    }

    /// Called only when sort parameters change — re-sort needed.
    func recomputeSortedCacheForSortChange() {
        cachedSortedFiles = files.sorted(by: sorter.compare)
        rebuildIndexByID()
    }

    /// Rebuilds the O(1) lookup dictionary and the rows array after list changes. Called only on list update.
    private func rebuildIndexByID() {
        // Build O(1) lookup dictionary: file ID → index
        var index = [CustomFile.ID: Int](minimumCapacity: cachedSortedFiles.count)

        for (offset, file) in cachedSortedFiles.enumerated() {
            // Parent entry should never be part of the navigation index
            // Also guard against cached ".." rows restored without the flag
            if file.isParentEntry || file.nameStr == ".." { continue }
            index[file.id] = offset
        }
        cachedIndexByID = index
        // Build UI rows array.
        // Ensure only one parent entry exists even if scanner already produced one.
        var rows: [CustomFile] = []
        rows.reserveCapacity(cachedSortedFiles.count + 1)

        let currentPath = appState.path(for: panelSide)

        // Always create exactly one synthetic parent row (UI responsibility)
        if currentPath != "/" {
            rows.append(CustomFile.parentLink(from: currentPath))
        }

        // Append filesystem entries but NEVER include parent entries from scanner or cache
        for file in cachedSortedFiles {
            // Drop any parent entries coming from scanner or cache
            if file.isParentEntry || file.nameStr == ".." { continue }
            rows.append(file)
        }

        cachedSortedRows = rows
    }

    /// Register navigation callbacks so DuoFilePanelKeyboardHandler
    /// can dispatch Up/Down/PgUp/PgDown/Home/End directly through AppState
    /// instead of relying on NSEvent passthrough to SwiftUI .onKeyPress.
    func registerNavigationCallbacks() {
        appState.navigationCallbacks[panelSide] = PanelNavigationCallbacks(
            moveUp: { [self] in keyboardNav.moveUp() },
            moveDown: { [self] in keyboardNav.moveDown() },
            pageUp: { [self] in keyboardNav.pageUp() },
            pageDown: { [self] in keyboardNav.pageDown() },
            jumpToFirst: { [self] in keyboardNav.jumpToFirst() },
            jumpToLast: { [self] in keyboardNav.jumpToLast() }
        )
    }
}
