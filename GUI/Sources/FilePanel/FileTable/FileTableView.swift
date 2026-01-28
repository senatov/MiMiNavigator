// FileTableView.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 11.08.2024.
// Refactored: 27.01.2026
// Copyright © 2024-2026 Senatov. All rights reserved.
// Description: Main file table view with sortable, resizable columns

import SwiftUI
import UniformTypeIdentifiers

// MARK: - File Table View
/// Displays file list with sortable columns, keyboard navigation, and drag-drop support
struct FileTableView: View {
    @Environment(AppState.self) var appState
    @Environment(DragDropManager.self) var dragDropManager
    
    let panelSide: PanelSide
    let files: [CustomFile]
    @Binding var selectedID: CustomFile.ID?
    let onSelect: (CustomFile) -> Void
    let onDoubleClick: (CustomFile) -> Void
    
    // MARK: - Local State
    @State private var sortKey: SortKeysEnum = .name
    @State private var sortAscending: Bool = true
    @State private var cachedSortedFiles: [CustomFile] = []
    @State private var scrollProxy: ScrollViewProxy?
    @State private var isPanelDropTargeted: Bool = false
    
    // MARK: - Column Widths
    @State private var sizeColumnWidth: CGFloat = TableColumnDefaults.size
    @State private var dateColumnWidth: CGFloat = TableColumnDefaults.date
    @State private var typeColumnWidth: CGFloat = TableColumnDefaults.type
    @State private var permissionsColumnWidth: CGFloat = TableColumnDefaults.permissions
    @State private var ownerColumnWidth: CGFloat = TableColumnDefaults.owner
    
    // MARK: - Computed Properties
    private var isFocused: Bool { appState.focusedPanel == panelSide }
    private var columnStorage: ColumnWidthStorage { ColumnWidthStorage(panelSide: panelSide) }
    private var sorter: TableFileSorter { TableFileSorter(sortKey: sortKey, ascending: sortAscending) }
    
    private var keyboardNav: TableKeyboardNavigation {
        TableKeyboardNavigation(
            files: cachedSortedFiles,
            selectedID: $selectedID,
            onSelect: onSelect,
            scrollProxy: scrollProxy
        )
    }
    
    private var dropHandler: TableDropHandler {
        TableDropHandler(panelSide: panelSide, appState: appState, dragDropManager: dragDropManager)
    }
    
    private var sortedRows: [(offset: Int, element: CustomFile)] {
        Array(cachedSortedFiles.enumerated())
    }
    
    // MARK: - Body
    var body: some View {
        ScrollViewReader { proxy in
            mainScrollView
                .onAppear {
                    scrollProxy = proxy
                    loadColumnWidths()
                    recomputeSortedCache()
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 6)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(panelBorder)
        .contentShape(Rectangle())
        .animation(nil, value: isFocused)
        .animation(nil, value: selectedID)
        .focusable(true)
        .focusEffectDisabled()
        .onChange(of: files) { recomputeSortedCache() }
        .onChange(of: sortKey) { recomputeSortedCache() }
        .onChange(of: sortAscending) { recomputeSortedCache() }
        .onChange(of: selectedID) { _, newValue in
            if let newID = newValue {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    keyboardNav.scrollToSelection(newID, anchor: .center)
                }
            }
        }
        .onMoveCommand { direction in
            guard isFocused else { return }
            switch direction {
            case .up: keyboardNav.moveUp()
            case .down: keyboardNav.moveDown()
            default: break
            }
        }
        .dropDestination(for: CustomFile.self) { droppedFiles, _ in
            dropHandler.handlePanelDrop(droppedFiles)
        } isTargeted: { targeted in
            withAnimation(.easeInOut(duration: 0.15)) {
                isPanelDropTargeted = targeted
            }
            dropHandler.updateDropTarget(targeted: targeted)
        }
    }
}

// MARK: - Subviews
private extension FileTableView {
    
    var mainScrollView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                TableHeaderView(
                    panelSide: panelSide,
                    sortKey: $sortKey,
                    sortAscending: $sortAscending,
                    sizeColumnWidth: $sizeColumnWidth,
                    dateColumnWidth: $dateColumnWidth,
                    typeColumnWidth: $typeColumnWidth,
                    permissionsColumnWidth: $permissionsColumnWidth,
                    ownerColumnWidth: $ownerColumnWidth,
                    onSave: saveColumnWidths
                )
                
                StableBy(cachedSortedFiles.count) {
                    FileTableRowsView(
                        rows: sortedRows,
                        selectedID: $selectedID,
                        panelSide: panelSide,
                        sizeColumnWidth: sizeColumnWidth,
                        dateColumnWidth: dateColumnWidth,
                        typeColumnWidth: typeColumnWidth,
                        permissionsColumnWidth: permissionsColumnWidth,
                        ownerColumnWidth: ownerColumnWidth,
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
        .background(keyboardShortcutsLayer)
    }
    
    var panelBorder: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .stroke(
                isPanelDropTargeted
                    ? Color.accentColor.opacity(0.8)
                    : (isFocused ? Color.accentColor.opacity(0.3) : Color.clear),
                lineWidth: isPanelDropTargeted ? 2 : 1
            )
            .allowsHitTesting(false)
    }
    
    var keyboardShortcutsLayer: some View {
        TableKeyboardShortcutsView(
            isFocused: isFocused,
            onPageUp: keyboardNav.jumpToFirst,
            onPageDown: keyboardNav.jumpToLast,
            onHome: keyboardNav.jumpToFirst,
            onEnd: keyboardNav.jumpToLast
        )
    }
}

// MARK: - Actions
private extension FileTableView {
    
    func handleFileAction(_ action: FileAction, for file: CustomFile) {
        log.debug("[FileTableView] FileAction: \(action) → \(file.nameStr)")
        ContextMenuCoordinator.shared.handleFileAction(action, for: file, panel: panelSide, appState: appState)
    }
    
    func handleDirectoryAction(_ action: DirectoryAction, for file: CustomFile) {
        log.debug("[FileTableView] DirectoryAction: \(action) → \(file.nameStr)")
        ContextMenuCoordinator.shared.handleDirectoryAction(action, for: file, panel: panelSide, appState: appState)
    }
}

// MARK: - State Management
private extension FileTableView {
    
    func loadColumnWidths() {
        let widths = columnStorage.load()
        sizeColumnWidth = widths.size
        dateColumnWidth = widths.date
        typeColumnWidth = widths.type
        permissionsColumnWidth = widths.permissions
        ownerColumnWidth = widths.owner
    }
    
    func saveColumnWidths() {
        columnStorage.save(
            size: sizeColumnWidth,
            date: dateColumnWidth,
            type: typeColumnWidth,
            permissions: permissionsColumnWidth,
            owner: ownerColumnWidth
        )
    }
    
    func recomputeSortedCache() {
        cachedSortedFiles = files.sorted(by: sorter.compare)
        log.debug("[FileTableView] sorted \(cachedSortedFiles.count) files by \(sortKey)")
    }
}
