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
            selectAndScroll(at: max(0, idx - 1))
        }

        func moveDown() {
            guard !files.isEmpty else { return }
            let idx = currentIndex()
            selectAndScroll(at: min(files.count - 1, idx + 1))
        }

        func pageUp() {
            guard !files.isEmpty else { return }
            let idx = currentIndex()
            selectAndScroll(at: max(startIndex, idx - pageStep))
        }

        func pageDown() {
            guard !files.isEmpty else { return }
            let idx = currentIndex()
            selectAndScroll(at: min(files.count - 1, idx + pageStep))
        }

        func jumpToFirst() {
            guard files.count > startIndex else { return }
            selectAndScroll(at: startIndex)
        }

        func jumpToLast() {
            guard !files.isEmpty else { return }
            selectAndScroll(at: files.count - 1)
        }

        // MARK: - Private helpers

        /// Returns the currently selected row index, including the parent entry if present.
        private func currentIndex() -> Int {
            guard let id = selectedID.wrappedValue else { return startIndex }

            // Parent entry is not present in indexByID, handle explicitly.
            if let first = files.first, first.id == id, first.isParentEntry {
                return 0
            }

            return indexByID[id] ?? startIndex
        }

        /// Start index for real filesystem entries (skips synthetic parent row if present)
        private var startIndex: Int {
            files.first?.isParentEntry == true ? 1 : 0
        }

        private func selectAndScroll(at index: Int) {
            // Protect against rare race conditions where the file list changes
            // between computing the index and accessing the array.
            guard files.indices.contains(index) else { return }

            let t0 = Date()
            let file = files[index]
            selectedID.wrappedValue = file.id
            onSelect(file)
            // Direct NSScrollView scroll — O(1), no cell materialization.
            // NEVER fall back to SwiftUI scrollTo — it's O(n) on LazyVStack
            // and causes 1s+ freezes even for 250 files.
            let appKitOK = scrollViaAppKit(toIndex: index)
            if !appKitOK {
                log.warning("[Nav] AppKit scroll FAILED for \(panelSide) idx=\(index) — NO fallback to SwiftUI scrollTo")
            }
            let ms = Int(Date().timeIntervalSince(t0) * 1000)
            log.debug("[Nav] idx=\(index) name=\(file.nameStr) selectAndScroll=\(ms)ms indexSize=\(files.count) appKit=\(appKitOK)")
        }

        /// Directly scroll the NSScrollView underlying SwiftUI ScrollView.
        /// Computes target offset as index * rowHeight — O(1), works for 26K+ items.
        /// Returns false if NSScrollView not found (fallback to SwiftUI scrollTo).
        private func scrollViaAppKit(toIndex index: Int) -> Bool {
            guard let window = NSApp.keyWindow ?? NSApp.mainWindow ?? NSApp.windows.first(where: { $0.isVisible }) else {
                log.debug("[Nav] scrollViaAppKit: no window found")
                return false
            }
            guard let scrollView = Self.findScrollView(in: window.contentView, panelSide: panelSide, windowWidth: window.frame.width)
            else {
                log.debug("[Nav] scrollViaAppKit: NSScrollView not found for \(panelSide)")
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

    // TableKeyboardShortcutsView removed — PgUp/PgDown/Home/End now handled
    // via .onKeyPress on FileTableView, which works regardless of scroll position.
