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

import Combine
import FileModelKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - File Table View

/// Displays file list with sortable columns, keyboard navigation, and drag-drop support
struct FileTableView: View {
    @Environment(AppState.self) var appState
    @Environment(DragDropManager.self) var dragDropManager

    let panelSide: FavPanelSide
    let files: [CustomFile]
    /// NOTE: selectedID is mapped to visible row IDs (including synthetic parent row)
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

    /// Cached real filesystem entries after sorting.
    /// This array does not include the synthetic parent-navigation row.
    @State var cachedSortedFiles: [CustomFile] = []

    /// O(1) lookup table: file.id → position in cachedSortedFiles.
    /// Rebuilt only when the file list changes.
    @State var cachedIndexByID: [CustomFile.ID: Int] = [:]

    /// Cached UI rows for LazyVStack.
    /// Unlike cachedSortedFiles, this array may include synthetic navigation rows
    /// such as the parent directory entry.
    @State var cachedSortedRows: [CustomFile] = []
    @State var isPanelDropTargeted: Bool = false

    /// Measured height of the scroll viewport — used to compute real pageStep
    @State var viewHeight: CGFloat = 400

    /// O(1) scroll target — set by keyboard nav, consumed by ScrollView(.scrollPosition)
    @State var scrollAnchorID: CustomFile.ID? = nil

    @State var showSpinner: Bool = false
    @State var spinnerTask: Task<Void, Never>? = nil

    @State var activeMenuTrackingCount: Int = 0
    @State var deferredFilesVersion: Int? = nil

    /// Throttle for PgUp/PgDown — prevents overwhelming with rapid keypresses
    let pageNavThrottle = KeypressThrottle(interval: 0.08)

    /// Wired to AppState loading flags — true while scanner refreshes this panel
    var isLoading: Bool {
        appState.isLoading(panelSide)
    }

    // MARK: - Column Layout
    let layout: ColumnLayoutModel

    // MARK: - Init
    init(
        panelSide: FavPanelSide,
        files: [CustomFile],
        selectedID: Binding<CustomFile.ID?>,
        layout: ColumnLayoutModel,
        onSelect: @escaping (CustomFile) -> Void,
        onDoubleClick: @escaping (CustomFile) -> Void
    ) {
        self.panelSide = panelSide
        self.files = files
        self._selectedID = selectedID
        self.layout = layout
        self.onSelect = onSelect
        self.onDoubleClick = onDoubleClick
    }

    // MARK: - Computed Properties
    var isFocused: Bool { appState.focusedPanel == panelSide }

    var sorter: TableFileSorter {
        TableFileSorter(sortKey: sortKey, ascending: sortAscending)
    }

    /// Number of fully visible rows based on measured viewport height.
    var visibleRowCount: Int {
        max(1, Int(floor(viewHeight / FilePanelStyle.rowHeight)))
    }

    var keyboardNav: TableKeyboardNavigation {
        TableKeyboardNavigation(
            files: cachedSortedFiles,
            indexByID: cachedIndexByID,
            selectedID: $selectedID,
            scrollAnchorID: $scrollAnchorID,
            onSelect: onSelect,
            pageStep: visibleRowCount,
            panelSide: panelSide
        )
    }

    var dropHandler: TableDropHandler {
        TableDropHandler(
            panelSide: panelSide,
            appState: appState,
            dragDropManager: dragDropManager
        )
    }

    /// O(1) version counter for the currently displayed panel file list.
    var filesVersion: Int {
        panelSide == .left ? appState.leftFilesVersion : appState.rightFilesVersion
    }

    var sortedRows: [CustomFile] { cachedSortedRows }

    func handleSortChange<T>(_: T) {
        recomputeSortedCacheForSortChange()
    }

    var body: some View {
        styledContentView
            .onAppear(perform: onAppear)
    }

}
