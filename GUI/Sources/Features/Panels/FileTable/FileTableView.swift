// FileTableView.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 11.08.2024.
// Copyright © 2024-2026 Senatov. All rights reserved.
// Description: Main file table view with sortable, resizable columns
//
// Architecture:
//   - FileTableView+Subviews.swift   → View components (scroll, border, shortcuts)
//   - FileTableView+Actions.swift    → Action handlers
//   - FileTableView+State.swift      → State management (columns, sorting)

import SwiftUI
import FileModelKit
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
    // sortKey and sortAscending live in AppState (single source of truth).
    // Local computed wrappers for convenience.
    var sortKey: SortKeysEnum {
        get { appState.sortKey }
        nonmutating set { appState.sortKey = newValue }
    }
    var sortAscending: Bool {
        get { appState.bSortAscending }
        nonmutating set { appState.bSortAscending = newValue }
    }
    @State var cachedSortedFiles: [CustomFile] = []
    /// Pre-built index map: file.id → position in cachedSortedFiles. Rebuilt only when list changes.
    @State var cachedIndexByID: [CustomFile.ID: Int] = [:]
    /// Pre-built enumerated rows for LazyVStack. Rebuilt only when list changes, not on selection.
    @State var cachedSortedRows: [(offset: Int, element: CustomFile)] = []
    @State var isPanelDropTargeted: Bool = false
    /// Measured height of the scroll viewport — used to compute real pageStep
    @State var viewHeight: CGFloat = 400
    /// O(1) scroll target — set by keyboard nav, consumed by ScrollView(.scrollPosition)
    @State var scrollAnchorID: CustomFile.ID? = nil

    // MARK: - Column Layout — owned by PanelFileTableSection, passed as Binding to avoid recreating on list updates
    @Binding var layout: ColumnLayoutModel

    // MARK: - Init
    init(
        panelSide: PanelSide,
        files: [CustomFile],
        selectedID: Binding<CustomFile.ID?>,
        layout: Binding<ColumnLayoutModel>,
        onSelect: @escaping (CustomFile) -> Void,
        onDoubleClick: @escaping (CustomFile) -> Void
    ) {
        self.panelSide = panelSide
        self.files = files
        self._selectedID = selectedID
        self._layout = layout
        self.onSelect = onSelect
        self.onDoubleClick = onDoubleClick
    }
    
    // MARK: - Computed Properties
    var isFocused: Bool { appState.focusedPanel == panelSide }

    var sorter: TableFileSorter { TableFileSorter(sortKey: sortKey, ascending: sortAscending) }
    
    /// Number of fully visible rows based on measured viewport height.
    var visibleRowCount: Int {
        max(1, Int(viewHeight / FilePanelStyle.rowHeight))
    }

    var keyboardNav: TableKeyboardNavigation {
        TableKeyboardNavigation(
            files: cachedSortedFiles,
            indexByID: cachedIndexByID,
            selectedID: $selectedID,
            scrollAnchorID: $scrollAnchorID,
            onSelect: onSelect,
            pageStep: visibleRowCount
        )
    }
    
    var dropHandler: TableDropHandler {
        TableDropHandler(panelSide: panelSide, appState: appState, dragDropManager: dragDropManager)
    }
    
    var sortedRows: [(offset: Int, element: CustomFile)] { cachedSortedRows }
    
    // MARK: - Body
    var body: some View {
        mainScrollView
            .onAppear {
                log.debug("\(#function) FileTableView onAppear panel=\(panelSide) files.count=\(files.count)")
                recomputeSortedCache()
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
        .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { viewHeight = $0 }
        // Compare version Int (O(1)) instead of [CustomFile] array (O(n)) — critical for 26k+ directories
        .onChange(of: panelSide == .left ? appState.leftFilesVersion : appState.rightFilesVersion) { recomputeSortedCache() }
        .onChange(of: appState.sortKey) { recomputeSortedCacheForSortChange() }
        .onChange(of: appState.bSortAscending) { recomputeSortedCacheForSortChange() }
        // No auto-scroll on selection change — user controls scroll position
        .onMoveCommand { direction in
            guard isFocused else { return }
            switch direction {
            case .up: keyboardNav.moveUp()
            case .down: keyboardNav.moveDown()
            default: break
            }
        }
        // PgUp/PgDown/Home/End via onKeyPress — works regardless of scroll position
        // .keyboardShortcut on hidden Buttons fails on unfocused ScrollView content
        .onKeyPress(.pageUp)    { guard isFocused else { return .ignored }; keyboardNav.pageUp();       return .handled }
        .onKeyPress(.pageDown)  { guard isFocused else { return .ignored }; keyboardNav.pageDown();     return .handled }
        .onKeyPress(.home)      { guard isFocused else { return .ignored }; keyboardNav.jumpToFirst();  return .handled }
        .onKeyPress(.end)       { guard isFocused else { return .ignored }; keyboardNav.jumpToLast();   return .handled }
        // ESC: clear marks only — never clear file selection.
        // Without this, SwiftUI resets the selectedID Binding to nil.
        .onKeyPress(.escape) {
            guard isFocused else { return .ignored }
            let markedCount = appState.markedCount(for: panelSide)
            if markedCount > 0 {
                appState.unmarkAll()
            }
            // Ensure a file stays selected — fall back to first if none
            appState.ensureSelectionOnFocusedPanel()
            return .handled
        }
        .dropDestination(for: URL.self) { droppedURLs, _ in
            // Prefer internal drag (preserves multi-selection), fallback to URL decode
            let droppedFiles = DropTargetModifier.safeResolveURLs(droppedURLs, dragDropManager: dragDropManager)
            guard !droppedFiles.isEmpty else { return false }
            return dropHandler.handlePanelDrop(droppedFiles)
        } isTargeted: { targeted in
            withAnimation(.easeInOut(duration: 0.15)) {
                isPanelDropTargeted = targeted
            }
            dropHandler.updateDropTarget(targeted: targeted)
        }
    }
}
