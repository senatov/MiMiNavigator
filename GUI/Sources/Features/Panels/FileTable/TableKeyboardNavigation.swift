// TableKeyboardNavigation.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 27.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Keyboard navigation logic for FileTableView

import SwiftUI
import FileModelKit

// MARK: - Table Keyboard Navigation
/// Handles keyboard-based file selection and navigation.
/// Uses an O(1) index lookup via a pre-built dictionary for large directories.
struct TableKeyboardNavigation {
    let files: [CustomFile]
    let selectedID: Binding<CustomFile.ID?>
    let onSelect: (CustomFile) -> Void
    let scrollProxy: ScrollViewProxy?
    /// Number of rows considered a "page" for PgUp/PgDown
    let pageStep: Int

    /// O(1) index lookup — avoids firstIndex O(n) scan on every keystroke.
    /// Built once at init time, not recomputed per keystroke.
    private let indexByID: [CustomFile.ID: Int]

    // MARK: - Init

    init(
        files: [CustomFile],
        selectedID: Binding<CustomFile.ID?>,
        onSelect: @escaping (CustomFile) -> Void,
        scrollProxy: ScrollViewProxy?,
        pageStep: Int = 20
    ) {
        self.files = files
        self.selectedID = selectedID
        self.onSelect = onSelect
        self.scrollProxy = scrollProxy
        self.pageStep = pageStep
        self.indexByID = Dictionary(uniqueKeysWithValues: files.enumerated().map { ($0.element.id, $0.offset) })
    }

    // MARK: - Navigation Actions

    func moveUp() {
        guard !files.isEmpty else { return }
        let idx = indexByID[selectedID.wrappedValue ?? ""] ?? 0
        selectAndScroll(at: max(0, idx - 1), anchor: .center)
    }

    func moveDown() {
        guard !files.isEmpty else { return }
        let idx = indexByID[selectedID.wrappedValue ?? ""] ?? -1
        selectAndScroll(at: min(files.count - 1, idx + 1), anchor: .center)
    }

    func pageUp() {
        guard !files.isEmpty else { return }
        let idx = indexByID[selectedID.wrappedValue ?? ""] ?? 0
        selectAndScroll(at: max(0, idx - pageStep), anchor: .top)
    }

    func pageDown() {
        guard !files.isEmpty else { return }
        let idx = indexByID[selectedID.wrappedValue ?? ""] ?? 0
        selectAndScroll(at: min(files.count - 1, idx + pageStep), anchor: .bottom)
    }

    func jumpToFirst() {
        guard let first = files.first else { return }
        selectAndScroll(file: first, anchor: .top)
    }

    func jumpToLast() {
        guard let last = files.last else { return }
        selectAndScroll(file: last, anchor: .bottom)
    }

    func scrollToSelection(_ id: CustomFile.ID?, anchor: UnitPoint = .center) {
        guard let id, let proxy = scrollProxy else { return }
        withAnimation(nil) {
            proxy.scrollTo(id, anchor: anchor)
        }
    }

    // MARK: - Private Helpers

    private func selectAndScroll(at index: Int, anchor: UnitPoint) {
        selectAndScroll(file: files[index], anchor: anchor)
    }

    private func selectAndScroll(file: CustomFile, anchor: UnitPoint) {
        selectedID.wrappedValue = file.id
        onSelect(file)
        scrollToSelection(file.id, anchor: anchor)
        log.debug("[TableKeyboardNavigation] selected: \(file.nameStr)")
    }
}

// TableKeyboardShortcutsView removed — PgUp/PgDown/Home/End now handled
// via .onKeyPress on FileTableView, which works regardless of scroll position.
