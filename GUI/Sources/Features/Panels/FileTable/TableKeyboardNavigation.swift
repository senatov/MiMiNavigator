// TableKeyboardNavigation.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 27.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Keyboard navigation logic for FileTableView.
//
// Scroll strategy: uses scrollAnchorID binding consumed by ScrollView.scrollPosition(id:).
// SwiftUI computes the scroll offset as index * rowHeight — O(1), no cell materialization.
// The old ScrollViewProxy.scrollTo(id:) approach was O(n) on LazyVStack:
// SwiftUI had to materialize all cells up to the target to determine its position.

import SwiftUI
import FileModelKit

// MARK: - Table Keyboard Navigation

/// Handles keyboard-based file selection and navigation.
/// Uses an O(1) index lookup via a pre-built dictionary for large directories.
struct TableKeyboardNavigation {
    let files: [CustomFile]
    let selectedID: Binding<CustomFile.ID?>
    /// Binding to ScrollView.scrollPosition(id:) — O(1) programmatic scroll
    let scrollAnchorID: Binding<CustomFile.ID?>
    let onSelect: (CustomFile) -> Void
    let pageStep: Int

    private let indexByID: [CustomFile.ID: Int]

    // MARK: - Init

    init(
        files: [CustomFile],
        selectedID: Binding<CustomFile.ID?>,
        scrollAnchorID: Binding<CustomFile.ID?>,
        onSelect: @escaping (CustomFile) -> Void,
        pageStep: Int = 20
    ) {
        self.files = files
        self.selectedID = selectedID
        self.scrollAnchorID = scrollAnchorID
        self.onSelect = onSelect
        self.pageStep = pageStep
        self.indexByID = Dictionary(uniqueKeysWithValues: files.enumerated().map { ($0.element.id, $0.offset) })
    }

    // MARK: - Navigation Actions

    func moveUp() {
        guard !files.isEmpty else { return }
        let idx = indexByID[selectedID.wrappedValue ?? ""] ?? 0
        selectAndScroll(at: max(0, idx - 1))
    }

    func moveDown() {
        guard !files.isEmpty else { return }
        let idx = indexByID[selectedID.wrappedValue ?? ""] ?? -1
        selectAndScroll(at: min(files.count - 1, idx + 1))
    }

    func pageUp() {
        guard !files.isEmpty else { return }
        let idx = indexByID[selectedID.wrappedValue ?? ""] ?? firstRealIndex
        selectAndScroll(at: max(firstRealIndex, idx - pageStep))
    }

    func pageDown() {
        guard !files.isEmpty else { return }
        let idx = indexByID[selectedID.wrappedValue ?? ""] ?? firstRealIndex
        selectAndScroll(at: min(files.count - 1, idx + pageStep))
    }

    func jumpToFirst() {
        guard files.count > firstRealIndex else { return }
        selectAndScroll(at: firstRealIndex)
    }

    func jumpToLast() {
        guard !files.isEmpty else { return }
        selectAndScroll(at: files.count - 1)
    }

    // MARK: - Private helpers

    /// Index of first real file — skips ".." parent entry at index 0.
    private var firstRealIndex: Int {
        if let first = files.first, ParentDirectoryEntry.isParentEntry(first) { return 1 }
        return 0
    }

    private func selectAndScroll(at index: Int) {
        let file = files[index]
        selectedID.wrappedValue = file.id
        onSelect(file)
        // O(1): SwiftUI uses index * rowHeight — no cell materialization
        scrollAnchorID.wrappedValue = file.id
        log.debug("[TableKeyboardNavigation] idx=\(index) file=\(file.nameStr)")
    }
}

// TableKeyboardShortcutsView removed — PgUp/PgDown/Home/End now handled
// via .onKeyPress on FileTableView, which works regardless of scroll position.
