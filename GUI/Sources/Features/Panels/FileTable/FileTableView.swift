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

        /// Throttle for PgUp/PgDown — prevents overwhelming with rapid keypresses
        private let pageNavThrottle = KeypressThrottle(interval: 0.08)  // 80ms between page navigations

        // MARK: - Column Layout — singleton from ColumnLayoutStore, no Binding needed
        let layout: ColumnLayoutModel

        // MARK: - Init
        init(
            panelSide: PanelSide,
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
        var sorter: TableFileSorter { TableFileSorter(sortKey: sortKey, ascending: sortAscending) }

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
            TableDropHandler(panelSide: panelSide, appState: appState, dragDropManager: dragDropManager)
        }

        /// O(1) version counter for the currently displayed panel file list.
        var filesVersion: Int {
            panelSide == .left ? appState.leftFilesVersion : appState.rightFilesVersion
        }

        var sortedRows: [CustomFile] { cachedSortedRows }

        /// Current selected file ID from AppState (source of truth for keyboard navigation).
        /// For the synthetic parent-navigation row, map AppState selection to the visible row ID
        /// from cachedSortedRows, because the visible parent row may be recreated with its own ID.
        private var selectedFileIDFromState: CustomFile.ID? {
            guard let selected = appState.panel(panelSide).selectedFile else {
                return nil
            }

            if selected.isParentEntry {
                return cachedSortedRows.first(where: { $0.isParentEntry })?.id
            }

            return selected.id
        }

        private func updateSelectedIndex(for newID: CustomFile.ID?) {
            if let id = newID,
               let rowIndex = cachedSortedRows.firstIndex(where: { $0.id == id }) {
                appState.setSelectedIndex(rowIndex, for: panelSide)
            } else {
                appState.setSelectedIndex(0, for: panelSide)
            }
        }

        // MARK: - Body
        var body: some View {
            let baseView = ZStack {
                mainScrollView

                // AppKit drop target — receives drops from other panels and external apps
                AppKitDropView(
                    panelSide: panelSide,
                    appState: appState,
                    dragDropManager: dragDropManager
                )

                // AppKit drag source — initiates multi-file drag via NSDraggingSession
                // (SwiftUI .onDrag only supports single NSItemProvider = single file)
                DragOverlayView(panelSide: panelSide)
            }

            return
                baseView
                .onAppear {
                    log.debug("\(#function) FileTableView onAppear panel=\(panelSide) files.count=\(files.count)")
                    recomputeSortedCache()
                    registerNavigationCallbacks()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 6)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(panelBorder)
                .contentShape(Rectangle())
                .animation(nil, value: isFocused)
                .animation(nil, value: selectedID)
                .transaction { $0.disablesAnimations = true }
                .focusable(true)
                .focusEffectDisabled()
                .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { viewHeight = $0 }
                // Compare version Int (O(1)) instead of [CustomFile] array (O(n)) — critical for 26k+ directories
                .onChange(of: filesVersion) { recomputeSortedCache() }
                .onChange(of: appState.sortKey) { recomputeSortedCacheForSortChange() }
                .onChange(of: appState.bSortAscending) { recomputeSortedCacheForSortChange() }
                // Update selectedIndex in AppState when selection changes — O(1) lookup via cachedIndexByID
                .onChange(of: selectedID) { _, newID in
                    updateSelectedIndex(for: newID)
                }
                // Sync Binding with AppState selection (needed for parent ".." row highlight)
                .onChange(of: selectedFileIDFromState) { _, newID in
                    if selectedID != newID {
                        selectedID = newID
                    }
                }
                // No auto-scroll on selection change — user controls scroll position
                // Up/Down via .onKeyPress — .onMoveCommand stopped delivering events
                // after custom keyboard handler changes. onKeyPress is reliable like PgUp/PgDown.
                .onKeyPress(.upArrow) {
                    guard isFocused else { return .ignored }
                    keyboardNav.moveUp()
                    return .handled
                }
                .onKeyPress(.downArrow) {
                    guard isFocused else { return .ignored }
                    keyboardNav.moveDown()
                    return .handled
                }
                // PgUp/PgDown/Home/End via onKeyPress — works regardless of scroll position
                // .keyboardShortcut on hidden Buttons fails on unfocused ScrollView content
                // Throttled to prevent UI freeze on rapid keypresses in large directories
                .onKeyPress(.pageUp) {
                    guard isFocused else { return .ignored }
                    if pageNavThrottle.allow() { keyboardNav.pageUp() }
                    return .handled
                }
                .onKeyPress(.pageDown) {
                    guard isFocused else { return .ignored }
                    if pageNavThrottle.allow() { keyboardNav.pageDown() }
                    return .handled
                }
                .onKeyPress(.home) {
                    guard isFocused else { return .ignored }
                    keyboardNav.jumpToFirst()
                    return .handled
                }
                .onKeyPress(.end) {
                    guard isFocused else { return .ignored }
                    keyboardNav.jumpToLast()
                    return .handled
                }
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
                // Jump-to-first / jump-to-last from status bar buttons
                .onReceive(NotificationCenter.default.publisher(for: .jumpToFirst).filter { ($0.object as? PanelSide) == panelSide }) {
                    _ in
                    keyboardNav.jumpToFirst()
                }
                .onReceive(NotificationCenter.default.publisher(for: .jumpToLast).filter { ($0.object as? PanelSide) == panelSide }) { _ in
                    keyboardNav.jumpToLast()
                }
        }
    }
