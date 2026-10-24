// FileTableView+State.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 04.02.2026.
// Copyright © 2024-2026 Senatov. All rights reserved.
// Description: State management for FileTableView (sorting, auto-fit)

import FileModelKit
import SwiftUI
import SwiftyBeaver

// MARK: - State Management
extension FileTableView {

    private static let log = SwiftyBeaver.self

    func recomputeSortedCache() {
        sortTask?.cancel()
        sortGeneration &+= 1
        let generation = sortGeneration
        let filesToSort = files
        let activeSorter = sorter
        if filesToSort.count < LargeDirectoryPolicy.largeEntryCount {
            applySortedSnapshot(.build(files: filesToSort, sorter: activeSorter))
            return
        }
        sortTask = Task { @MainActor in
            let worker = Task.detached(priority: .userInitiated) {
                FileTableSortedSnapshot.build(files: filesToSort, sorter: activeSorter)
            }
            let snapshot = await withTaskCancellationHandler {
                await worker.value
            } onCancel: {
                worker.cancel()
            }
            guard !Task.isCancelled, generation == sortGeneration else { return }
            applySortedSnapshot(snapshot)
        }
    }

    // MARK: - Apply Sorted Snapshot
    private func applySortedSnapshot(_ snapshot: FileTableSortedSnapshot) {
        layout.setContainsDirectories(snapshot.containsDirectories)
        layout.setContainsUsablePermissions(snapshot.containsUsablePermissions)
        cachedSortedRows = snapshot.rows
        cachedIndexByID = snapshot.indexByID
        firstVisibleRow = min(firstVisibleRow, max(0, snapshot.rows.count - 1))
        scrollToSelectionFromState()
        Self.log.debug("[FileTableState] rebuilt sorted cache panel=\(panelSide.rawValue) count=\(snapshot.rows.count) mode=\(LargeDirectoryPolicy.mode(for: snapshot.rows.count))")
    }

    /// Register navigation callbacks so DuoFilePanelKeyboardHandler
    /// can dispatch Up/Down/PgUp/PgDown/Home/End directly through AppState
    /// instead of relying on NSEvent passthrough to SwiftUI .onKeyPress.
    func registerNavigationCallbacks() {
        appState.navigationCallbacks[panelSide] = PanelNavigationCallbacks(
            moveUp: { [self] in
                handleMoveUpCommand()
            },
            moveDown: { [self] in
                keyboardNav.moveDown()
            },
            pageUp: { [self] in
                handlePageUpCommand()
            },
            pageDown: { [self] in
                keyboardNav.pageDown()
            },
            jumpToFirst: { [self] in
                keyboardNav.jumpToFirst()
            },
            jumpToLast: { [self] in
                keyboardNav.jumpToLast()
            }
        )

        Self.log.debug("[FileTableState] registered navigation callbacks panel=\(panelSide.rawValue)")
    }
}
