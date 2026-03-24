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
        panelSide: PanelSide
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
        // Protect against rare race conditions where the file list changes
        // between computing the index and accessing the array.
        guard index >= 0 && index < files.count else { return }
        let t0 = Date()
        let file = files[index]
        log.debug("\(logPrefix) resolved target idx=\(index) name='\(file.nameStr)' parent=\(isParentRow(file))")
        selectedID.wrappedValue = file.id
        onSelect(file)
        // Direct AppKit scroll (O(1)) — avoids LazyVStack materialization
        let appKitOK = scrollViaAppKit(toIndex: index)
        if !appKitOK {
            log.warning("\(logPrefix) AppKit scroll FAILED for \(panelSide) idx=\(index) — NO fallback to SwiftUI scrollTo")
        }
        let ms = Int(Date().timeIntervalSince(t0) * 1000)
        log.debug("\(logPrefix) select idx=\(index) name='\(file.nameStr)' time=\(ms)ms size=\(files.count) appKit=\(appKitOK)")
    }

    /// Directly scroll the NSScrollView underlying SwiftUI ScrollView.
    /// Computes target offset as index * rowHeight — O(1), works for 26K+ items.
    /// Returns false if NSScrollView not found (fallback to SwiftUI scrollTo).
    private func scrollViaAppKit(toIndex index: Int) -> Bool {
        guard let window = NSApp.keyWindow ?? NSApp.mainWindow ?? NSApp.windows.first(where: { $0.isVisible }) else {
            log.debug("\(logPrefix) scrollViaAppKit: no window found")
            return false
        }
        guard let scrollView = Self.findScrollView(in: window.contentView, panelSide: panelSide, windowWidth: window.frame.width)
        else {
            log.debug("\(logPrefix) scrollViaAppKit: NSScrollView not found for \(panelSide)")
            return false
        }
        let rowH = FilePanelStyle.rowHeight
        let headerEstimate: CGFloat = 30
        let targetY = CGFloat(index) * rowH + headerEstimate
        let clipHeight = scrollView.contentView.bounds.height
        let scrollY = max(0, targetY - clipHeight / 2)
        let maxY = max(0, scrollView.documentView!.frame.height - clipHeight)
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
