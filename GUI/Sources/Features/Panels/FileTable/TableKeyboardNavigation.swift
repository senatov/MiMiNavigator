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

import AppKit
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
    // Injected from outside — built once when list changes, not on every keypress
    private let indexByID: [CustomFile.ID: Int]

    // MARK: - Init

    init(
        files: [CustomFile],
        indexByID: [CustomFile.ID: Int],
        selectedID: Binding<CustomFile.ID?>,
        scrollAnchorID: Binding<CustomFile.ID?>,
        onSelect: @escaping (CustomFile) -> Void,
        pageStep: Int = 20
    ) {
        self.files = files
        self.indexByID = indexByID
        self.selectedID = selectedID
        self.scrollAnchorID = scrollAnchorID
        self.onSelect = onSelect
        self.pageStep = pageStep
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
        let t0 = Date()
        let file = files[index]
        selectedID.wrappedValue = file.id
        onSelect(file)

        // Try direct NSScrollView scroll first — O(1), no cell materialization.
        // Falls back to scrollAnchorID (SwiftUI scrollTo) for small lists.
        if !scrollViaAppKit(toIndex: index) {
            scrollAnchorID.wrappedValue = file.id
        }
        let ms = Int(Date().timeIntervalSince(t0) * 1000)
        log.debug("[Nav] idx=\(index) name=\(file.nameStr) selectAndScroll=\(ms)ms indexSize=\(files.count)")
    }

    /// Directly scroll the NSScrollView underlying SwiftUI ScrollView.
    /// Computes target offset as index * rowHeight — O(1), works for 26K+ items.
    /// Returns false if NSScrollView not found (fallback to SwiftUI scrollTo).
    private func scrollViaAppKit(toIndex index: Int) -> Bool {
        guard let window = NSApp.keyWindow else { return false }
        // Find the NSClipView that hosts our LazyVStack
        guard let scrollView = Self.findScrollView(in: window.contentView) else { return false }
        let rowH = FilePanelStyle.rowHeight
        // +1 accounts for "..." parent entry row and header
        let headerEstimate: CGFloat = 30
        let targetY = CGFloat(index) * rowH + headerEstimate
        let clipHeight = scrollView.contentView.bounds.height
        // Center the target row in the visible area
        let scrollY = max(0, targetY - clipHeight / 2)
        let maxY = max(0, scrollView.documentView!.frame.height - clipHeight)
        let clampedY = min(scrollY, maxY)
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: clampedY))
        scrollView.reflectScrolledClipView(scrollView.contentView)
        return true
    }

    /// Walk the view hierarchy to find the first NSScrollView (SwiftUI's backing scroll)
    private static func findScrollView(in view: NSView?) -> NSScrollView? {
        guard let view else { return nil }
        if let sv = view as? NSScrollView,
           sv.documentView != nil,
           sv.documentView!.frame.height > 1000 { // Our file list, not a small popup
            return sv
        }
        for sub in view.subviews {
            if let found = findScrollView(in: sub) { return found }
        }
        return nil
    }
}

// TableKeyboardShortcutsView removed — PgUp/PgDown/Home/End now handled
// via .onKeyPress on FileTableView, which works regardless of scroll position.
