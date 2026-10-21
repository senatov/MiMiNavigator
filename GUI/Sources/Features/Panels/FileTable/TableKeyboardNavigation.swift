// TableKeyboardNavigation.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 27.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Keyboard navigation logic for FileTableView.
//   Parent strip is now a separate panel outside the table —
//   this struct works only with real filesystem entries.
//
// Scroll strategy: reveal the selected row at the nearest visible edge.

import FileModelKit
import SwiftUI

// MARK: - Table Keyboard Navigation

/// Handles keyboard-based file selection and navigation.
/// Uses an O(1) index lookup via a pre-built dictionary for large directories.
/// Parent ".." entry is NOT in the files array — it lives in ParentNavigationStripPanel.
@MainActor
struct TableKeyboardNavigation {
    let files: [CustomFile]
    let selectedID: Binding<CustomFile.ID?>
    let onScrollToRow: (Int, CustomFile.ID) -> Void
    let onSelect: (CustomFile) -> Void
    let pageStep: Int
    // Injected from outside — built once when list changes, not on every keypress
    private let indexByID: [CustomFile.ID: Int]

    // MARK: - Init

    init(
        files: [CustomFile],
        indexByID: [CustomFile.ID: Int],
        selectedID: Binding<CustomFile.ID?>,
        onScrollToRow: @escaping (Int, CustomFile.ID) -> Void,
        onSelect: @escaping (CustomFile) -> Void,
        pageStep: Int = 20
    ) {
        self.files = files
        self.indexByID = indexByID
        self.selectedID = selectedID
        self.onScrollToRow = onScrollToRow
        self.onSelect = onSelect
        self.pageStep = pageStep
    }

    // MARK: - Navigation Actions

    func moveUp() {
        guard !files.isEmpty else { return }
        // Already on parent strip — stay there
        if selectedID.wrappedValue == nil { return }
        let idx = currentIndex()
        if idx == 0 {
            return
        }
        selectAndScroll(at: idx - 1)
    }


    func moveDown() {
        guard !files.isEmpty else { return }
        // Coming from parent strip (selectedID == nil) → land on first real file
        if selectedID.wrappedValue == nil {
            selectAndScroll(at: 0)
            return
        }
        let idx = currentIndex()
        let last = files.count - 1
        if idx == last { return }
        selectAndScroll(at: idx + 1)
    }


    func pageUp() {
        guard !files.isEmpty else { return }
        // From parent strip → land on first file
        guard let _ = selectedID.wrappedValue else {
            selectAndScroll(at: 0)
            return
        }
        let idx = currentIndex()
        if idx == 0 {
            return
        }
        let target = max(0, idx - pageStep)
        selectAndScroll(at: target)
    }


    func pageDown() {
        guard !files.isEmpty else { return }
        // From parent strip → land on first file
        guard let _ = selectedID.wrappedValue else {
            selectAndScroll(at: min(files.count - 1, pageStep))
            return
        }
        let idx = currentIndex()
        selectAndScroll(at: min(files.count - 1, idx + pageStep))
    }


    func jumpToFirst() {
        guard !files.isEmpty else { return }
        selectAndScroll(at: 0)
    }


    func jumpToLast() {
        guard !files.isEmpty else { return }
        selectAndScroll(at: files.count - 1)
    }

    // MARK: - Private helpers

    /// Returns the currently selected row index.
    private func currentIndex() -> Int {
        guard let id = selectedID.wrappedValue else { return 0 }
        return indexByID[id] ?? 0
    }


    private func selectAndScroll(at index: Int) {
        guard index >= 0 && index < files.count else { return }
        let file = files[index]
        selectedID.wrappedValue = file.id
        onSelect(file)
        onScrollToRow(index, file.id)
    }
}
