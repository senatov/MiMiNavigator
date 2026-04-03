// TableKeyboardNavigation.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 27.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Keyboard navigation logic for FileTableView.
//
// Scroll strategy: uses ScrollViewReader.scrollTo(id:) — Finder-style minimum scroll.
// Only scrolls when the target row is outside the visible rect; reveals at nearest edge.

import FileModelKit
import SwiftUI

// MARK: - Table Keyboard Navigation

/// Handles keyboard-based file selection and navigation.
/// Uses an O(1) index lookup via a pre-built dictionary for large directories.
@MainActor
struct TableKeyboardNavigation {
    let files: [CustomFile]
    let selectedID: Binding<CustomFile.ID?>
    /// Legacy binding — retained for API compatibility but no longer drives scrolling.
    let scrollAnchorID: Binding<CustomFile.ID?>
    let onSelect: (CustomFile) -> Void
    let pageStep: Int
    let panelSide: FavPanelSide
    // Injected from outside — built once when list changes, not on every keypress
    private let indexByID: [CustomFile.ID: Int]

    private let logPrefix = "[Nav]"

    // MARK: - Init

    init(
        files: [CustomFile],
        indexByID: [CustomFile.ID: Int],
        selectedID: Binding<CustomFile.ID?>,
        scrollAnchorID: Binding<CustomFile.ID?>,
        onSelect: @escaping (CustomFile) -> Void,
        pageStep: Int = 20,
        panelSide: FavPanelSide
    ) {
        self.files = files
        self.indexByID = indexByID
        self.selectedID = selectedID
        self.scrollAnchorID = scrollAnchorID
        self.onSelect = onSelect
        self.pageStep = pageStep
        self.panelSide = panelSide
    }

    // MARK: - Navigation Actions

    func moveUp() {
        guard !files.isEmpty else { return }
        let idx = currentIndex()

        // Already at parent entry — do nothing
        if idx == 0 { return }

        let previousIndex = idx - 1

        // Special UX: only when moving FROM first real file → parent entry
        if idx == firstRealFileIndex {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                selectAndScroll(at: 0)
            }
            log.debug("\(logPrefix) ↑ from first real file → parent entry")
            return
        }

        selectAndScroll(at: previousIndex)
    }

    func moveDown() {
        guard !files.isEmpty else { return }
        let idx = currentIndex()
        let last = files.count - 1
        if idx == last { return }
        selectAndScroll(at: idx + 1)
    }

    func pageUp() {
        guard !files.isEmpty else { return }

        let idx = currentIndex()
        let target = max(firstRealFileIndex, idx - pageStep)

        guard files.indices.contains(target) else { return }

        let file = files[target]
        if isParentRow(file) {
            log.error("\(logPrefix) pageUp resolved to parent entry at idx=\(target); forcing first real file")
            if files.indices.contains(firstRealFileIndex) {
                selectAndScroll(at: firstRealFileIndex)
            }
            return
        }

        selectAndScroll(at: target)
    }

    func pageDown() {
        guard !files.isEmpty else { return }
        let idx = currentIndex()
        selectAndScroll(at: min(files.count - 1, idx + pageStep))
    }

    func jumpToFirst() {
        guard files.indices.contains(firstRealFileIndex) else { return }
        // Jump-to-first targets the first real file, not the synthetic parent entry.
        selectAndScroll(at: firstRealFileIndex)
    }

    func jumpToLast() {
        guard !files.isEmpty else { return }
        selectAndScroll(at: files.count - 1)
    }

    // MARK: - Private helpers

    private func isParentRow(_ file: CustomFile) -> Bool {
        // Primary detection
        if ParentDirectoryEntry.isParentEntry(file) { return true }

        // Fallback: UI may provide synthetic ".." without flag
        return file.nameStr == ".."
    }

    /// Returns the currently selected row index, including the parent entry if present.
    private func currentIndex() -> Int {
        guard let id = selectedID.wrappedValue else { return firstRealFileIndex }

        if let first = files.first, isParentRow(first), first.id == id {
            return 0
        }
        return indexByID[id] ?? firstRealFileIndex
    }

    private func isAlreadySelected(_ file: CustomFile, index: Int) -> Bool {
        if selectedID.wrappedValue == file.id {
            log.debug("\(logPrefix) skip — already selected idx=\(index) name='\(file.nameStr)'")
            return true
        }
        return false
    }

    /// Index of the first real filesystem entry.
    /// The synthetic parent row ("..") is never a PageUp/jump-to-first target.
    private var firstRealFileIndex: Int {
        guard let first = files.first else { return 0 }
        return isParentRow(first) ? 1 : 0
    }

    private func selectAndScroll(at index: Int) {
        guard index >= 0 && index < files.count else { return }
        let file = files[index]
        log.debug("\(logPrefix) resolved target idx=\(index) name='\(file.nameStr)' parent=\(isParentRow(file))")
        selectedID.wrappedValue = file.id
        onSelect(file)
        // Reset anchor to nil first so onChange fires even for same ID
        scrollAnchorID.wrappedValue = nil
        scrollAnchorID.wrappedValue = file.id
    }

}
