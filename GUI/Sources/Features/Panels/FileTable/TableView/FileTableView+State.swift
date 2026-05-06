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

    private struct FilesSnapshot: Equatable {
        let count: Int
        let firstHash: Int
        let lastHash: Int

        var combinedHash: Int {
            count ^ firstHash ^ lastHash
        }
    }

    private func makeFilesSnapshot() -> FilesSnapshot {
        let firstHash = files.first?.id.hashValue ?? 0
        let lastHash = files.last?.id.hashValue ?? 0

        return FilesSnapshot(
            count: files.count,
            firstHash: firstHash,
            lastHash: lastHash
        )
    }

    private func shouldSkipSortedCacheRebuild(snapshot: FilesSnapshot) -> Bool {
        guard Self.lastFilesHash[panelSide] == snapshot.combinedHash else {
            return false
        }

        return cachedSortedFiles.count == snapshot.count
    }

    private func storeFilesSnapshot(_ snapshot: FilesSnapshot) {
        Self.lastFilesHash[panelSide] = snapshot.combinedHash
    }

    private func makeSortedRows(from sortedFiles: [CustomFile], currentPath: String) -> [CustomFile] {
        var rows: [CustomFile] = []
        rows.reserveCapacity(sortedFiles.count)

        // Parent ".." strip is now a separate panel (ParentNavigationStripPanel)
        // — no longer injected into the rows array.

        for file in sortedFiles where shouldIncludeInRows(file) {
            rows.append(file)
        }

        return rows
    }

    private func makeIndexByID(from sortedFiles: [CustomFile]) -> [CustomFile.ID: Int] {
        var index = [CustomFile.ID: Int](minimumCapacity: sortedFiles.count)

        for (offset, file) in sortedFiles.enumerated() where shouldIncludeInRows(file) {
            index[file.id] = offset
        }

        return index
    }

    private func shouldIncludeInRows(_ file: CustomFile) -> Bool {
        !file.isParentEntry && file.nameStr != ".."
    }

    /// Track last files reference to skip redundant rebuilds
    private static var lastFilesHash: [FavPanelSide: Int] = [:]

    func recomputeSortedCache(force: Bool = false) {
        let snapshot = makeFilesSnapshot()

        if !force, shouldSkipSortedCacheRebuild(snapshot: snapshot) {
            Self.log.debug(
                "[FileTableState] skip cache rebuild panel=\(panelSide.rawValue) count=\(snapshot.count) hash=\(snapshot.combinedHash)"
            )
            return
        }

        storeFilesSnapshot(snapshot)
        cachedSortedFiles = files
        rebuildIndexByID()

        Self.log.debug(
            "[FileTableState] rebuilt cache panel=\(panelSide.rawValue) count=\(snapshot.count) hash=\(snapshot.combinedHash) force=\(force)")
    }

    /// Called only when sort parameters change — re-sort needed.
    func recomputeSortedCacheForSortChange() {
        cachedSortedFiles = files.sorted(by: sorter.compare)
        rebuildIndexByID()

        Self.log.debug(
            "[FileTableState] rebuilt sorted cache after sort change panel=\(panelSide.rawValue) count=\(cachedSortedFiles.count)")
    }

    /// Rebuilds the O(1) lookup dictionary and the rows array after list changes. Called only on list update.
    private func rebuildIndexByID() {
        let currentPath = appState.path(for: panelSide)
        cachedSortedRows = makeSortedRows(from: cachedSortedFiles, currentPath: currentPath)
        // Build index from rows (not raw files) so positions match what keyboardNav sees
        cachedIndexByID = makeIndexByID(from: cachedSortedRows)

        Self.log.debug(
            "[FileTableState] rebuilt rows panel=\(panelSide.rawValue) files=\(cachedSortedFiles.count) rows=\(cachedSortedRows.count) index=\(cachedIndexByID.count) path='\(currentPath)'"
        )
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
