// FileTableView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 11.08.2024.
//  Copyright © 2024 Senatov. All rights reserved.
//

import SwiftUI

// MARK: - File table view with sortable columns
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
    @State private var scrollProxy: ScrollViewProxy? = nil
    @State private var isScrollingProgrammatically = false
    
    private var isFocused: Bool { appState.focusedPanel == panelSide }
    
    fileprivate var px: CGFloat {
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        return 1.0 / scale
    }
    
    private var sortedRows: [(offset: Int, element: CustomFile)] {
        Array(cachedSortedFiles.enumerated())
    }

    var body: some View {
        ScrollViewReader { proxy in
            mainScrollView(proxy: proxy)
                .onAppear { scrollProxy = proxy }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 6)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(focusBorder)
        .overlay(lightBorder)
        .contentShape(Rectangle())
        .animation(nil, value: isFocused)
        .animation(nil, value: selectedID)
        .focusable(true)
        .onAppear { recomputeSortedCache() }
        .onChange(of: files) { recomputeSortedCache() }
        .onChange(of: sortKey) { recomputeSortedCache() }
        .onChange(of: sortAscending) { recomputeSortedCache() }
        .onChange(of: selectedID) { _, newValue in
            if let newID = newValue {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    scrollToSelection(newID, anchor: .center)
                }
            }
        }
        .onMoveCommand { direction in
            guard isFocused else { return }
            switch direction {
            case .up: moveSelectionUp()
            case .down: moveSelectionDown()
            default: break
            }
        }
    }

    // MARK: - Keyboard navigation
    private func moveSelectionUp() {
        guard !cachedSortedFiles.isEmpty else { return }
        let currentIndex = cachedSortedFiles.firstIndex { $0.id == selectedID } ?? 0
        let newIndex = max(0, currentIndex - 1)
        let newFile = cachedSortedFiles[newIndex]
        selectedID = newFile.id
        onSelect(newFile)
        scrollToSelection(newFile.id, anchor: .center)
    }
    
    private func moveSelectionDown() {
        guard !cachedSortedFiles.isEmpty else { return }
        let currentIndex = cachedSortedFiles.firstIndex { $0.id == selectedID } ?? -1
        let newIndex = min(cachedSortedFiles.count - 1, currentIndex + 1)
        let newFile = cachedSortedFiles[newIndex]
        selectedID = newFile.id
        onSelect(newFile)
        scrollToSelection(newFile.id, anchor: .center)
    }
    
    private func jumpToFirst() {
        guard let firstFile = cachedSortedFiles.first else { return }
        selectedID = firstFile.id
        onSelect(firstFile)
        scrollToSelection(firstFile.id, anchor: .top)
    }
    
    private func jumpToLast() {
        guard let lastFile = cachedSortedFiles.last else { return }
        selectedID = lastFile.id
        onSelect(lastFile)
        scrollToSelection(lastFile.id, anchor: .bottom)
    }
    
    private func scrollToSelection(_ id: CustomFile.ID?, anchor: UnitPoint = .center) {
        guard let id = id, let proxy = scrollProxy else { return }
        isScrollingProgrammatically = true
        withAnimation(nil) {
            proxy.scrollTo(id, anchor: anchor)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isScrollingProgrammatically = false
        }
    }
    
    private func recomputeSortedCache() {
        cachedSortedFiles = files.sorted(by: compare)
    }

    // MARK: - Main scroll view
    @ViewBuilder
    private func mainScrollView(proxy: ScrollViewProxy) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                headerView()
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
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: 40)
        }
        .background(keyboardShortcutsLayer(proxy: proxy))
    }

    // MARK: - Header with sortable columns
    @ViewBuilder
    private func headerView() -> some View {
        HStack(spacing: 6) {
            getNameColSortableHeader()
            headerColumnDivider
            getSizeColSortableHeader()
            headerColumnDivider
            getDateSortableHeader()
            headerColumnDivider
            getTypeColSortableHeader()
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(
            LinearGradient(
                colors: [
                    Color(nsColor: .systemBlue).opacity(0.04),
                    Color(nsColor: .systemGray).opacity(0.01),
                    Color.black.opacity(0.15),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.black.opacity(0.15))
                .frame(height: max(px, 1.0))
                .allowsHitTesting(false)
        }
    }

    private var headerColumnDivider: some View {
        Rectangle()
            .fill(Color.black.opacity(0.4))
            .frame(width: px)
            .padding(.vertical, 3)
            .allowsHitTesting(false)
    }

    @ViewBuilder
    private func keyboardShortcutsLayer(proxy: ScrollViewProxy) -> some View {
        ZStack {
            Button(action: { guard isFocused else { return }; jumpToFirst() }) { EmptyView() }
                .keyboardShortcut(.pageUp, modifiers: [])
            Button(action: { guard isFocused else { return }; jumpToLast() }) { EmptyView() }
                .keyboardShortcut(.pageDown, modifiers: [])
            Button(action: { guard isFocused else { return }; jumpToFirst() }) { EmptyView() }
                .keyboardShortcut(.home, modifiers: [])
            Button(action: { guard isFocused else { return }; jumpToLast() }) { EmptyView() }
                .keyboardShortcut(.end, modifiers: [])
        }
        .frame(width: 0, height: 0)
        .opacity(0.001)
        .allowsHitTesting(false)
    }

    private var focusBorder: some View {
        RoundedRectangle(cornerRadius: 12)
            .stroke(
                isFocused ? Color(nsColor: .systemIndigo) : Color.secondary.opacity(0.8),
                lineWidth: isFocused ? 0.8 : 0.4
            )
            .allowsHitTesting(false)
    }

    private var lightBorder: some View {
        RoundedRectangle(cornerRadius: 12)
            .stroke(Color.white.opacity(isFocused ? 0.10 : 0.05), lineWidth: 1)
            .allowsHitTesting(false)
    }

    // MARK: - Column headers
    private func getNameColSortableHeader() -> some View {
        HStack(spacing: 4) {
            Text("Name").font(.subheadline).fontWeight(.medium)
            if sortKey == .name {
                Image(systemName: sortAscending ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                    .font(.caption2)
                    .foregroundStyle(Color.accentColor)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            appState.focusedPanel = panelSide
            if sortKey == .name { sortAscending.toggle() }
            else { sortKey = .name; sortAscending = true }
            appState.updateSorting(key: .name, ascending: sortAscending)
        }
    }

    private func getSizeColSortableHeader() -> some View {
        HStack(spacing: 4) {
            Text("Size").font(.subheadline).fontWeight(.medium)
            if sortKey == .size {
                Image(systemName: sortAscending ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                    .font(.caption2)
                    .foregroundStyle(Color.accentColor)
            }
        }
        .frame(width: FilePanelStyle.sizeColumnWidth, alignment: .trailing)
        .contentShape(Rectangle())
        .onTapGesture {
            appState.focusedPanel = panelSide
            if sortKey == .size { sortAscending.toggle() }
            else { sortKey = .size; sortAscending = true }
            appState.updateSorting(key: .size, ascending: sortAscending)
        }
    }

    private func getDateSortableHeader() -> some View {
        HStack(spacing: 4) {
            Text("Date").font(.subheadline).fontWeight(.medium)
            if sortKey == .date {
                Image(systemName: sortAscending ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                    .font(.caption2)
                    .foregroundStyle(Color.accentColor)
            }
        }
        .frame(width: FilePanelStyle.modifiedColumnWidth, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            appState.focusedPanel = panelSide
            if sortKey == .date { sortAscending.toggle() }
            else { sortKey = .date; sortAscending = true }
            appState.updateSorting(key: .date, ascending: sortAscending)
        }
    }
    
    private func getTypeColSortableHeader() -> some View {
        HStack(spacing: 4) {
            Text("Type").font(.subheadline).fontWeight(.medium)
            if sortKey == .type {
                Image(systemName: sortAscending ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                    .font(.caption2)
                    .foregroundStyle(Color.accentColor)
            }
        }
        .frame(width: FilePanelStyle.typeColumnWidth, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            appState.focusedPanel = panelSide
            if sortKey == .type { sortAscending.toggle() }
            else { sortKey = .type; sortAscending = true }
            appState.updateSorting(key: .type, ascending: sortAscending)
        }
    }

    // MARK: - Action handlers
    func handleFileAction(_ action: FileAction, for file: CustomFile) {
        log.debug("FileAction: \(action) → \(file.pathStr)")
    }

    func handleDirectoryAction(_ action: DirectoryAction, for file: CustomFile) {
        log.debug("DirectoryAction: \(action) → \(file.pathStr)")
    }

    // MARK: - Sorting comparator
    func compare(_ a: CustomFile, _ b: CustomFile) -> Bool {
        let aIsFolder = a.isDirectory || a.isSymbolicDirectory
        let bIsFolder = b.isDirectory || b.isSymbolicDirectory
        if aIsFolder != bIsFolder { return aIsFolder && !bIsFolder }
        
        switch sortKey {
        case .name:
            let cmp = a.nameStr.localizedCaseInsensitiveCompare(b.nameStr)
            return sortAscending ? (cmp == .orderedAscending) : (cmp == .orderedDescending)
        case .size:
            let lhs = a.sizeInBytes
            let rhs = b.sizeInBytes
            if lhs != rhs { return sortAscending ? (lhs < rhs) : (lhs > rhs) }
            return a.nameStr.localizedCaseInsensitiveCompare(b.nameStr) == .orderedAscending
        case .date:
            let lhs = a.modifiedDate ?? Date.distantPast
            let rhs = b.modifiedDate ?? Date.distantPast
            if lhs != rhs { return sortAscending ? (lhs < rhs) : (lhs > rhs) }
            return a.nameStr.localizedCaseInsensitiveCompare(b.nameStr) == .orderedAscending
        case .type:
            let lhs = a.fileExtension
            let rhs = b.fileExtension
            if lhs != rhs {
                let cmp = lhs.localizedCaseInsensitiveCompare(rhs)
                return sortAscending ? (cmp == .orderedAscending) : (cmp == .orderedDescending)
            }
            return a.nameStr.localizedCaseInsensitiveCompare(b.nameStr) == .orderedAscending
        }
    }
}
