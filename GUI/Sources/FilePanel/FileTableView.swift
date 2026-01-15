// FileTableView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 11.08.2024.
//  Copyright © 2024 Senatov. All rights reserved.

import SwiftUI

// MARK: - File table view with sortable and resizable columns
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
    
    // MARK: - Resizable column widths (persisted per panel)
    @State private var sizeColumnWidth: CGFloat = ColumnDefaults.size
    @State private var dateColumnWidth: CGFloat = ColumnDefaults.date
    @State private var typeColumnWidth: CGFloat = ColumnDefaults.type
    
    // MARK: - Column defaults and constraints
    private enum ColumnDefaults {
        static let size: CGFloat = 65
        static let date: CGFloat = 115
        static let type: CGFloat = 50
    }
    
    private enum ColumnConstraints {
        static let sizeMin: CGFloat = 40
        static let sizeMax: CGFloat = 120
        static let dateMin: CGFloat = 50
        static let dateMax: CGFloat = 180
        static let typeMin: CGFloat = 30
        static let typeMax: CGFloat = 100
    }
    
    // MARK: - Header style
    private enum HeaderStyle {
        static let font = Font.system(size: 12, weight: .semibold, design: .default)
        static let color = Color(red: 0.1, green: 0.2, blue: 0.45)
    }
    
    // MARK: - UserDefaults keys
    private var sizeWidthKey: String { "FileTable.\(panelSide).sizeWidth" }
    private var dateWidthKey: String { "FileTable.\(panelSide).dateWidth" }
    private var typeWidthKey: String { "FileTable.\(panelSide).typeWidth" }
    
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
                .onAppear {
                    scrollProxy = proxy
                    loadColumnWidths()
                }
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
    
    // MARK: - Persistence
    private func loadColumnWidths() {
        let defaults = UserDefaults.standard
        if let size = defaults.object(forKey: sizeWidthKey) as? CGFloat, size > 0 {
            sizeColumnWidth = size
        }
        if let date = defaults.object(forKey: dateWidthKey) as? CGFloat, date > 0 {
            dateColumnWidth = date
        }
        if let type = defaults.object(forKey: typeWidthKey) as? CGFloat, type > 0 {
            typeColumnWidth = type
        }
    }
    
    private func saveColumnWidths() {
        let defaults = UserDefaults.standard
        defaults.set(sizeColumnWidth, forKey: sizeWidthKey)
        defaults.set(dateColumnWidth, forKey: dateWidthKey)
        defaults.set(typeColumnWidth, forKey: typeWidthKey)
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
                        sizeColumnWidth: sizeColumnWidth,
                        dateColumnWidth: dateColumnWidth,
                        typeColumnWidth: typeColumnWidth,
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

    // MARK: - Header with sortable and resizable columns
    @ViewBuilder
    private func headerView() -> some View {
        HStack(spacing: 0) {
            // Name column (flexible)
            getNameColSortableHeader()
            
            // Divider before Size
            resizableDivider(
                width: $sizeColumnWidth,
                min: ColumnConstraints.sizeMin,
                max: ColumnConstraints.sizeMax
            )
            
            // Size column
            getSizeColSortableHeader()
                .frame(width: sizeColumnWidth, alignment: .trailing)
                .padding(.horizontal, 4)
            
            // Divider before Date
            resizableDivider(
                width: $dateColumnWidth,
                min: ColumnConstraints.dateMin,
                max: ColumnConstraints.dateMax
            )
            
            // Date column
            getDateSortableHeader()
                .frame(width: dateColumnWidth, alignment: .leading)
                .padding(.horizontal, 4)
            
            // Divider before Type
            resizableDivider(
                width: $typeColumnWidth,
                min: ColumnConstraints.typeMin,
                max: ColumnConstraints.typeMax
            )
            
            // Type column
            getTypeColSortableHeader()
                .frame(width: typeColumnWidth, alignment: .leading)
                .padding(.horizontal, 4)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 6)
        .background(
            LinearGradient(
                colors: [
                    Color(nsColor: .systemBlue).opacity(0.06),
                    Color(nsColor: .windowBackgroundColor).opacity(0.95),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.black.opacity(0.2))
                .frame(height: max(px, 1.0))
                .allowsHitTesting(false)
        }
    }

    // MARK: - Resizable column divider
    private func resizableDivider(width: Binding<CGFloat>, min: CGFloat, max: CGFloat) -> some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor))
            .frame(width: 1)
            .padding(.vertical, 2)
            .overlay {
                Color.clear
                    .frame(width: 12)
                    .contentShape(Rectangle())
            }
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        let delta = value.translation.width
                        let newWidth = width.wrappedValue - delta
                        width.wrappedValue = Swift.min(Swift.max(newWidth, min), max)
                    }
                    .onEnded { _ in
                        saveColumnWidths()
                    }
            )
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
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
            Text("Name")
                .font(HeaderStyle.font)
                .foregroundStyle(HeaderStyle.color)
            if sortKey == .name {
                Image(systemName: sortAscending ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(HeaderStyle.color)
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
            Text("Size")
                .font(HeaderStyle.font)
                .foregroundStyle(HeaderStyle.color)
            if sortKey == .size {
                Image(systemName: sortAscending ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(HeaderStyle.color)
            }
        }
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
            Text("Date")
                .font(HeaderStyle.font)
                .foregroundStyle(HeaderStyle.color)
            if sortKey == .date {
                Image(systemName: sortAscending ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(HeaderStyle.color)
            }
        }
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
            Text("Type")
                .font(HeaderStyle.font)
                .foregroundStyle(HeaderStyle.color)
            if sortKey == .type {
                Image(systemName: sortAscending ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(HeaderStyle.color)
            }
        }
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
