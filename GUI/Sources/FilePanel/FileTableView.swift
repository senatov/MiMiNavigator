//
// FileRowView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 11.08.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import SwiftUI

// MARK: -
struct FileTableView: View {
    @Environment(AppState.self) var appState
    let panelSide: PanelSide
    let files: [CustomFile]
    @Binding var selectedID: CustomFile.ID?
    let onSelect: (CustomFile) -> Void
    let onDoubleClick: (CustomFile) -> Void
    @State private var sortKey: SortKeysEnum = .name
    @State private var sortAscending: Bool = true
    @State private var cachedSortedFiles: [CustomFile] = []
    @State private var lastBodyLogTime: TimeInterval? = nil
    @State private var scrollProxy: ScrollViewProxy? = nil
    @State private var isScrollingProgrammatically = false
    
    // MARK: - Keyboard Navigation
    /// Move selection up by one item
    private func moveSelectionUp() {
        guard !cachedSortedFiles.isEmpty else { return }
        let currentIndex = cachedSortedFiles.firstIndex { $0.id == selectedID } ?? 0
        let newIndex = max(0, currentIndex - 1)
        let newFile = cachedSortedFiles[newIndex]
        selectedID = newFile.id
        onSelect(newFile)
        scrollToSelection(newFile.id, anchor: .center)
    }
    
    /// Move selection down by one item
    private func moveSelectionDown() {
        guard !cachedSortedFiles.isEmpty else { return }
        let currentIndex = cachedSortedFiles.firstIndex { $0.id == selectedID } ?? -1
        let newIndex = min(cachedSortedFiles.count - 1, currentIndex + 1)
        let newFile = cachedSortedFiles[newIndex]
        selectedID = newFile.id
        onSelect(newFile)
        scrollToSelection(newFile.id, anchor: .center)
    }
    
    /// Jump to first item (Home/PageUp)
    private func jumpToFirst() {
        guard let firstFile = cachedSortedFiles.first else { return }
        selectedID = firstFile.id
        onSelect(firstFile)
        scrollToSelection(firstFile.id, anchor: .top)
        log.debug("[NAV] Jump to FIRST on <<\(panelSide)>>")
    }
    
    /// Jump to last item (End/PageDown)
    private func jumpToLast() {
        guard let lastFile = cachedSortedFiles.last else { return }
        selectedID = lastFile.id
        onSelect(lastFile)
        scrollToSelection(lastFile.id, anchor: .bottom)
        log.debug("[NAV] Jump to LAST on <<\(panelSide)>>")
    }
    
    /// Instant scroll without animation
    private func scrollToSelection(_ id: CustomFile.ID?, anchor: UnitPoint = .center) {
        guard let id = id, let proxy = scrollProxy else {
            log.debug("[SCROLL] scrollToSelection skipped: id=\(id == nil ? "nil" : "set") proxy=\(scrollProxy == nil ? "nil" : "set") side=<<\(panelSide)>>")
            return
        }
        log.debug("[SCROLL] scrollToSelection: id=\(id) anchor=\(anchor) side=<<\(panelSide)>>")
        isScrollingProgrammatically = true
        // Use withAnimation(nil) to ensure instant scroll without animation
        withAnimation(nil) {
            proxy.scrollTo(id, anchor: anchor)
        }
        // Reset flag after short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isScrollingProgrammatically = false
        }
    }
    fileprivate var px: CGFloat {
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        return 1.0 / scale
    }

    // Keeps a stable sorted array->avoid ScrollView content rebuilds on every render
    private func recomputeSortedCache() {
        // Always sort dirs first, then apply sel'd column sort
        let base: [CustomFile] = files
        let sorted = base.sorted(by: compare)
        cachedSortedFiles = sorted
        if cachedSortedFiles.count != sorted.count || true {
            log.debug("recomputeSortedCache → side= <<\(panelSide)>> key=\(sortKey) asc=\(sortAscending) count=\(sorted.count)")
        }
    }
    // Precomputed rows to ease type checker
    private var sortedRows: [(offset: Int, element: CustomFile)] {
        let rows = Array(cachedSortedFiles.enumerated())
        return rows
    }
    // Focus state helper
    private var isFocused: Bool { appState.focusedPanel == panelSide }

    // MARK: -
    var body: some View {
        ScrollViewReader { proxy in
            mainScrollView(proxy: proxy)
                .onAppear {
                    scrollProxy = proxy
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 6)
        // Clip content to the same rounded shape as the outer borders,
        // so header background corners visually match side borders.
        .clipShape(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay(focusBorder)
        .overlay(lightBorder)
        .contentShape(Rectangle())
        .animation(nil, value: isFocused)
        .transaction { txn in txn.disablesAnimations = true }
        .animation(nil, value: selectedID)
        .focusable(true)
        .onAppear { recomputeSortedCache() }
        .onChange(of: files) { recomputeSortedCache() }
        .onChange(of: sortKey) { recomputeSortedCache() }
        .onChange(of: sortAscending) { recomputeSortedCache() }
        // Auto-scroll to keep selected item visible when selection changes (mouse click)
        .onChange(of: selectedID) { oldValue, newValue in
            log.debug("[SCROLL] selectedID changed: \(oldValue ?? "nil") → \(newValue ?? "nil") side=<<\(panelSide)>>")
            if let newID = newValue {
                // Small delay to let SwiftUI finish layout updates
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    scrollToSelection(newID, anchor: .center)
                }
            }
        }
        // Arrow key navigation - instant response, no animation
        .onMoveCommand { direction in
            guard isFocused else { return }
            switch direction {
            case .up:
                moveSelectionUp()
            case .down:
                moveSelectionDown()
            default:
                break
            }
        }
    }

    // MARK: -
    @ViewBuilder
    private func mainScrollView(proxy: ScrollViewProxy) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                headerView()
                // Note: Do NOT include selectedID in StableBy key - it causes scroll reset on selection change
                StableBy(cachedSortedFiles.count) {
                    FileTableRowsView(
                        rows: sortedRows,
                        selectedID: $selectedID,
                        panelSide: panelSide,
                        onSelect: onSelect,
                        onDoubleClick: onDoubleClick,
                        handleFileAction: handleFileAction,
                        handleDirectoryAction: handleDirectoryAction
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(
                    GeometryReader { gp in
                        Color.clear
                            .onAppear {
                                log.debug("FTV.content appear → size=\(Int(gp.size.width))x\(Int(gp.size.height)) on \(panelSide)")
                            }
                            .onChange(of: gp.size) {
                                // Throttle viewport content size logs
                                let now = ProcessInfo.processInfo.systemUptime
                                if now - (lastBodyLogTime ?? 0) > 0.25 {  // introduce local cache below
                                    lastBodyLogTime = now
                                    log.debug(
                                        "FTV.content size changed → \(Int(gp.size.width))x\(Int(gp.size.height)) on <<\(panelSide)>>")
                                }
                            }
                    }
                )
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            // Reserve space for bottom toolbar - prevents last items from being cut off
            Color.clear.frame(height: 40)
        }
        .background(
            GeometryReader { gp in
                Color.clear
                    .onAppear {
                        log.debug("FTV.viewport appear → size=\(Int(gp.size.width))x\(Int(gp.size.height)) on <<\(panelSide)>>")
                    }
                    .onChange(of: gp.size) {
                        let now = ProcessInfo.processInfo.systemUptime
                        if now - (lastBodyLogTime ?? 0) > 0.25 {
                            lastBodyLogTime = now
                            log.debug("FTV.viewport size changed → \(Int(gp.size.width))x\(Int(gp.size.height)) on <<\(panelSide)>>")
                        }
                    }
            }
        )
        .background(keyboardShortcutsLayer(proxy: proxy))
    }

    // MARK: -
    @ViewBuilder
    private func headerView() -> some View {
        HStack(spacing: 8) {
            getNameColSortableHeader()
            headerColumnDivider
            getSizeColSortableHeader()
            headerColumnDivider
            getDateSortableHeader()
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(
            LinearGradient(
                colors: [
                    Color(nsColor: .systemBlue).opacity(0.040),
                    Color(nsColor: .systemGray).opacity(0.010),
                    Color.black.opacity(0.15),  // subtle shadow edge
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(nsColor: .systemBlue).opacity(0.040),  // top bright blue highlight
                            Color(nsColor: .systemBlue).opacity(0.010),  // mid blue
                            Color.black.opacity(0.15),  // subtle shadow edge
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: max(px, 1.0))
                .allowsHitTesting(false)
        }
    }

    // MARK: - Header divider
    private var headerColumnDivider: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.46),
                        Color.black.opacity(0.36),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: px)
            .padding(.vertical, 3)
            .allowsHitTesting(false)
    }

    // MARK: - Keyboard shortcuts layer
    @ViewBuilder
    private func keyboardShortcutsLayer(proxy: ScrollViewProxy) -> some View {
        // Invisible buttons to capture PageUp/PageDown/Home/End - TC-style navigation
        ZStack {
            // PageUp → jump to first item
            Button(action: {
                guard isFocused else { return }
                jumpToFirst()
            }) { EmptyView() }
            .keyboardShortcut(.pageUp, modifiers: [])

            // PageDown → jump to last item  
            Button(action: {
                guard isFocused else { return }
                jumpToLast()
            }) { EmptyView() }
            .keyboardShortcut(.pageDown, modifiers: [])
            
            // Home → jump to first item
            Button(action: {
                guard isFocused else { return }
                jumpToFirst()
            }) { EmptyView() }
            .keyboardShortcut(.home, modifiers: [])
            
            // End → jump to last item
            Button(action: {
                guard isFocused else { return }
                jumpToLast()
            }) { EmptyView() }
            .keyboardShortcut(.end, modifiers: [])
        }
        .frame(width: 0, height: 0)
        .opacity(0.001)
        .allowsHitTesting(false)
    }

    // MARK: - Tab Borders
    private var focusBorder: some View {
        RoundedRectangle(cornerRadius: 12)
            .stroke(
                isFocused ? Color(#colorLiteral(red: 0.09019608051, green: 0, blue: 0.3019607961, alpha: 1)) : Color(Color.secondary).opacity(0.8),
                lineWidth: isFocused ? 0.8 : 0.4
            )
            .allowsHitTesting(false)
    }

    // MARK: -
    private var lightBorder: some View {
        RoundedRectangle(cornerRadius: 12)
            .stroke(Color.white.opacity(isFocused ? 0.10 : 0.05), lineWidth: 1)
            .allowsHitTesting(false)
    }

    // MARK: - File actions handler
    func handleFileAction(_ action: FileAction, for file: CustomFile) {
        log.debug(#function + ": \(action)")
        switch action {
            case .cut:
                log.debug("File action: cut → \(file.pathStr)")
            case .copy:
                log.debug("File action: copy → \(file.pathStr)")
            case .pack:
                log.debug("File action: pack → \(file.pathStr)")
            case .viewLister:
                log.debug("File action: viewLister → \(file.pathStr)")
            case .createLink:
                log.debug("File action: createLink → \(file.pathStr)")
            case .delete:
                log.debug("File action: delete → \(file.pathStr)")
            case .rename:
                log.debug("File action: rename → \(file.pathStr)")
            case .properties:
                log.debug("File action: properties → \(file.pathStr)")
        }
    }

    // MARK: -
    private func getNameColSortableHeader() -> some View {
        return HStack(spacing: 4) {
            Text("Name").font(.subheadline)
            if sortKey == .name {
                Image(systemName: sortAscending ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill").font(.caption2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
        .onTapGesture {
            log.debug("Name header tapped on side: <<\(panelSide)>>")
            appState.focusedPanel = panelSide
            if sortKey == .name {
                sortAscending.toggle()
            } else {
                sortKey = .name
                sortAscending = true
            }
            appState.updateSorting(key: .name, ascending: sortAscending)
        }
    }

    // MARK: -
    private func getSizeColSortableHeader() -> some View {
        return HStack(spacing: 4) {
            Text("Size").font(.subheadline)
            if sortKey == .size {
                Image(systemName: sortAscending ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill").font(.caption2)
            }
        }
        .frame(width: FilePanelStyle.sizeColumnWidth, alignment: .leading).contentShape(Rectangle())
        .onTapGesture {
            appState.focusedPanel = panelSide
            log.debug("Size header tapped on side: <<\(panelSide)>>")
            if sortKey == .size {
                sortAscending.toggle()
            } else {
                sortKey = .size
                sortAscending = true
            }
            appState.updateSorting(key: .size, ascending: sortAscending)
        }
    }

    // MARK: -
    private func getDateSortableHeader() -> some View {
        return HStack(spacing: 4) {
            Text("Date").font(.subheadline)
            if sortKey == .date {
                Image(systemName: sortAscending ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill").font(.caption2)
            }
        }
        .frame(width: FilePanelStyle.modifiedColumnWidth + 10, alignment: .leading).contentShape(Rectangle())
        .onTapGesture {
            appState.focusedPanel = panelSide
            log.debug("Date header tapped on side: <<\(panelSide)>>")
            if sortKey == .date {
                sortAscending.toggle()
            } else {
                sortKey = .date
                sortAscending = true
            }
            appState.updateSorting(key: .date, ascending: sortAscending)
        }
    }

    // MARK: - Directory actions handler
    func handleDirectoryAction(_ action: DirectoryAction, for file: CustomFile) {
        log.debug(#function + " for \(file.pathStr)")
        switch action {
            case .open:
                log.debug("Action: open → \(file.pathStr)")
            case .openInNewTab:
                log.debug("Action: openInNewTab → \(file.pathStr)")
            case .viewLister:
                log.debug("Action: viewLister → \(file.pathStr)")
            case .cut:
                log.debug("Action: cut → \(file.pathStr)")
            case .copy:
                log.debug("Action: copy → \(file.pathStr)")
            case .pack:
                log.debug("Action: pack → \(file.pathStr)")
            case .createLink:
                log.debug("Action: createLink → \(file.pathStr)")
            case .delete:
                log.debug("Action: delete → \(file.pathStr)")
            case .rename:
                log.debug("Action: rename → \(file.pathStr)")
            case .properties:
                log.debug("Action: properties → \(file.pathStr)")
        }
    }

    // MARK: - Sorting comparator extracted to help the type-checker
    func compare(_ a: CustomFile, _ b: CustomFile) -> Bool {
        let aIsFolder = a.isDirectory || a.isSymbolicDirectory
        let bIsFolder = b.isDirectory || b.isSymbolicDirectory
        if aIsFolder != bIsFolder { return aIsFolder && !bIsFolder }
        switch sortKey {
            case .name:
                let cmp = a.nameStr.localizedCaseInsensitiveCompare(b.nameStr)
                return sortAscending ? (cmp == .orderedAscending) : (cmp == .orderedDescending)

            case .size:
                let lhs: Int64 = a.sizeInBytes
                let rhs: Int64 = b.sizeInBytes
                if lhs != rhs { return sortAscending ? (lhs < rhs) : (lhs > rhs) }
                return a.nameStr.localizedCaseInsensitiveCompare(b.nameStr) == .orderedAscending

            case .date:
                let lhs = a.modifiedDate ?? Date.distantPast
                let rhs = b.modifiedDate ?? Date.distantPast
                if lhs != rhs { return sortAscending ? (lhs < rhs) : (lhs > rhs) }
                return a.nameStr.localizedCaseInsensitiveCompare(b.nameStr) == .orderedAscending
        }
    }

}
