// TableKeyboardNavigation.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 27.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Keyboard navigation logic for FileTableView.
//
// Keyboard navigation for FileTableView (O(1) index lookup + AppKit scrolling)

import AppKit
import FileModelKit
import SwiftUI

// MARK: - Table Keyboard Navigation

/// Handles keyboard-based file selection and navigation.
/// Uses an O(1) index lookup via a pre-built dictionary for large directories.
@MainActor
struct TableKeyboardNavigation {
    let files: [CustomFile]
    let selectedID: Binding<CustomFile.ID?>
    /// Binding to ScrollView.scrollPosition(id:) — O(1) programmatic scroll
    let scrollAnchorID: Binding<CustomFile.ID?>
    let onSelect: (CustomFile) -> Void
    let pageStep: Int
    let panelSide: PanelSide
    /// Callback to move focus outside the table (e.g. to "go to parent" button)
    let onMoveFocusToParent: (() -> Void)?
    // Injected from outside — built once when list changes, not on every keypress
    private let indexByID: [CustomFile.ID: Int]

    // MARK: - Init

    init(
        files: [CustomFile],
        indexByID: [CustomFile.ID: Int],
        selectedID: Binding<CustomFile.ID?>,
        scrollAnchorID: Binding<CustomFile.ID?>,
        onSelect: @escaping (CustomFile) -> Void,
        pageStep: Int = 20,
        panelSide: PanelSide,
        onMoveFocusToParent: (() -> Void)? = nil
    ) {
        self.files = files
        self.indexByID = indexByID
        self.selectedID = selectedID
        self.scrollAnchorID = scrollAnchorID
        self.onSelect = onSelect
        self.pageStep = pageStep
        self.panelSide = panelSide
        self.onMoveFocusToParent = onMoveFocusToParent
    }

    private func resolvedIndex() -> Int? {
        // If selection is lost (e.g. focus moved outside), fallback to top
        guard let id = selectedID.wrappedValue else {
            log.debug("[Nav] resolvedIndex: nil selection → fallback idx=0")
            return files.isEmpty ? nil : 0
        }

        if let idx = indexByID[id] {
            return idx
        }

        // fallback: parent entry at top
        if let first = files.first,
            first.id == id,
            first.isParentEntry
        {
            log.debug("[Nav] resolvedIndex: parent entry idx=0")
            return 0
        }

        return nil
    }

    // MARK: - Navigation Actions

    func moveUp() {
        guard !files.isEmpty else { return }

        guard let idx = resolvedIndex() else {
            log.debug("[Nav] moveUp: no resolved index")
            return
        }

        log.debug("[Nav] ↑ idx=\(idx)")

        if idx == 0 {
            log.debug("[Nav] TOP → move focus to parent button")
            onMoveFocusToParent?()
            return
        }

        selectAndScroll(at: idx - 1)
    }

    func moveDown() {
        guard !files.isEmpty else { return }

        guard let idx = resolvedIndex() else {
            log.debug("[Nav] moveDown: no resolved index")
            return
        }

        let next = min(files.count - 1, idx + 1)

        log.debug("[Nav] ↓ idx=\(idx) → \(next)")

        selectAndScroll(at: next)
    }

    func pageUp() {
        guard !files.isEmpty else { return }
        guard let idx = resolvedIndex() else {
            log.debug("[Nav] pageUp: no resolved index")
            return
        }
        log.debug("[Nav] pageUp idx=\(idx) → \(max(0, idx - pageStep))")
        selectAndScroll(at: max(0, idx - pageStep))
    }

    func pageDown() {
        guard !files.isEmpty else { return }
        guard let idx = resolvedIndex() else {
            log.debug("[Nav] pageDown: no resolved index")
            return
        }
        log.debug("[Nav] pageDown idx=\(idx) → \(min(files.count - 1, idx + pageStep))")
        selectAndScroll(at: min(files.count - 1, idx + pageStep))
    }

    func jumpToFirst() {
        guard !files.isEmpty else { return }
        log.debug("[Nav] jumpToFirst")
        selectAndScroll(at: 0)
    }

    func jumpToLast() {
        guard !files.isEmpty else { return }
        log.debug("[Nav] jumpToLast")
        selectAndScroll(at: files.count - 1)
    }

    // MARK: - Private helpers
    private func selectAndScroll(at index: Int) {
        // Protect against rare race conditions where the file list changes
        // between computing the index and accessing the array.
        guard files.indices.contains(index) else { return }
        let t0 = Date()
        let file = files[index]
        // Update selection only if changed to avoid redundant work
        if selectedID.wrappedValue != file.id {
            selectedID.wrappedValue = file.id
        }
        // Direct NSScrollView scroll — O(1), no cell materialization.
        // NEVER fall back to SwiftUI scrollTo — it's O(n) on LazyVStack
        // and causes 1s+ freezes even for 250 files.
        let appKitOK = scrollViaAppKit(toIndex: index)
        if !appKitOK {
            log.warning("[Nav] AppKit scroll FAILED for \(panelSide) idx=\(index) — NO fallback to SwiftUI scrollTo")
        }
        // Call onSelect after scroll to avoid side-effects interfering with scroll timing.
        onSelect(file)
        let ms = Int(Date().timeIntervalSince(t0) * 1000)
        log.debug("[Nav] idx=\(index) name=\(file.nameStr) time=\(ms)ms appKit=\(appKitOK)")
    }

    /// AppKit scroll: index → offset (O(1))
    private func scrollViaAppKit(toIndex index: Int) -> Bool {
        guard let window = NSApp.keyWindow ?? NSApp.mainWindow ?? NSApp.windows.first(where: { $0.isVisible }) else {
            log.warning("[Nav] scroll: no window")
            return false
        }
        guard let scrollView = Self.findScrollView(in: window.contentView, panelSide: panelSide, windowWidth: window.frame.width)
        else {
            log.warning("[Nav] scroll: no scrollView for \(panelSide)")
            return false
        }
        let rowH = FilePanelStyle.rowHeight
        let headerEstimate: CGFloat = 30
        let targetY = CGFloat(index) * rowH + headerEstimate
        let clipHeight = scrollView.contentView.bounds.height
        let scrollY = max(0, targetY - clipHeight / 2)
        guard let doc = scrollView.documentView else {
            log.warning("[Nav] scrollViaAppKit: missing documentView")
            return false
        }
        let maxY = max(0, doc.frame.height - clipHeight)
        let clampedY = min(scrollY, maxY)
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: clampedY))
        scrollView.reflectScrolledClipView(scrollView.contentView)
        return true
    }

    /// Walk the view hierarchy to find the NSScrollView belonging to the correct panel.
    /// Panels are side-by-side: left panel ScrollView has frame.minX < windowWidth/2,
    /// right panel ScrollView has frame.minX > windowWidth/2.
    private static func findScrollView(in view: NSView?, panelSide: PanelSide, windowWidth: CGFloat) -> NSScrollView? {
        guard let view else { return nil }
        if let sv = view as? NSScrollView,
            sv.documentView != nil,
            sv.documentView!.frame.height > 100
        {
            // Determine which panel this ScrollView belongs to by its X position in window coords
            let frameInWindow = sv.convert(sv.bounds, to: nil)
            let midX = frameInWindow.midX
            let isLeft = midX < windowWidth / 2
            if (panelSide == .left && isLeft) || (panelSide == .right && !isLeft) {
                return sv
            }
        }
        for sub in view.subviews {
            if let found = findScrollView(in: sub, panelSide: panelSide, windowWidth: windowWidth) {
                return found
            }
        }
        return nil
    }
}
