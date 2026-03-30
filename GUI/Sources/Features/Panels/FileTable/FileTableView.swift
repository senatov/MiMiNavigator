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

    @State private var showSpinner: Bool = false
    @State private var spinnerTask: Task<Void, Never>? = nil
    /// Path for which autoFit already ran — prevents re-fitting on FSEvents refreshes
    @State private var lastAutoFitPath: String = ""
    /// Container width at last autoFit — re-fit when delta > threshold
    @State private var lastAutoFitWidth: CGFloat = 0
    /// Pending autofit task — waits for all sizes to settle before running
    @State private var pendingAutoFitTask: Task<Void, Never>?

    /// Throttle for PgUp/PgDown — prevents overwhelming with rapid keypresses
    private let pageNavThrottle = KeypressThrottle(interval: 0.08)  // 80ms between page navigations

    /// Wired to AppState loading flags — true while scanner refreshes this panel
    private var isLoading: Bool {
        appState.isLoading(panelSide)
    }

    // MARK: - Column Layout — singleton from ColumnLayoutStore, no Binding needed
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

    var filesRenderIdentity: Int {
        var hasher = Hasher()
        hasher.combine(panelSide)
        hasher.combine(filesVersion)
        hasher.combine(files.count)
        for file in files {
            hasher.combine(file.id)
            hasher.combine(file.nameStr)
            hasher.combine(file.pathStr)
            hasher.combine(file.isDirectory)
            hasher.combine(file.isParentEntry)
        }
        return hasher.finalize()
    }

    var sortedRows: [CustomFile] { cachedSortedRows }

    private var contentView: some View {
        ZStack {
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

            if showSpinner {
                spinnerView
            }
        }
    }

    private var spinnerView: some View {
        ProgressView()
            .controlSize(.small)
            .scaleEffect(0.9)
            .frame(maxWidth: CGFloat.infinity, maxHeight: CGFloat.infinity)
            .allowsHitTesting(false)
            .transition(.opacity)
    }

    private var styledContentView: some View {
        contentView
            .frame(maxWidth: CGFloat.infinity, maxHeight: CGFloat.infinity)
            .padding(.leading, 6)
            .padding(.trailing, ScrollBarConfig.trailingPadding)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(panelBorder)
            .contentShape(Rectangle())
            .animation(nil as Animation?, value: isFocused)
            .animation(nil as Animation?, value: selectedID)
            .animation(nil as Animation?, value: filesVersion)
            .transaction { transaction in
                transaction.disablesAnimations = true
            }
            .focusable(true)
            .focusEffectDisabled()
            .onGeometryChange(
                for: CGFloat.self,
                of: { geometry in
                    geometry.size.height
                }
            ) { newHeight in
                viewHeight = newHeight
            }
            .onChange(of: layout.containerWidth) { _, newWidth in
                handleContainerWidthChange(newWidth)
            }
            .onChange(of: filesVersion) { _, newValue in
                handleFilesVersionChange(newValue)
            }
            .onChange(of: appState.sortKey) { _, newValue in
                handleSortChange(newValue)
            }
            .onChange(of: appState.bSortAscending) { _, newValue in
                handleSortChange(newValue)
            }
            .onChange(of: selectedID) { _, newValue in
                handleSelectionChange(newValue)
            }
            .onChange(of: selectedFileIDFromState) { _, newValue in
                syncSelectionFromState(newValue)
            }
            .onChange(of: isLoading) { _, loading in
                handleLoadingChange(loading)
            }
            .onKeyPress(.upArrow, action: handleUpArrow)
            .onKeyPress(.downArrow, action: handleDownArrow)
            .onKeyPress(.pageUp, action: handlePageUp)
            .onKeyPress(.pageDown, action: handlePageDown)
            .onKeyPress(.home, action: handleHome)
            .onKeyPress(.end, action: handleEnd)
            .onKeyPress(.escape, action: handleEscape)
            .onReceive(jumpToFirstPublisher, perform: handleJumpToFirst)
            .onReceive(jumpToLastPublisher, perform: handleJumpToLast)
            .onDisappear {
                spinnerTask?.cancel()
                pendingAutoFitTask?.cancel()
            }
    }

    var body: some View {
        styledContentView
            .id(filesRenderIdentity)
            .onAppear(perform: onAppear)
    }

    private func isParentRow(_ file: CustomFile) -> Bool {
        ParentDirectoryEntry.isParentEntry(file) || file.nameStr == ".."
    }

    /// Compare a visible row with a selectedID, handling synthetic parent row correctly
    private func isSameRow(_ file: CustomFile, id: CustomFile.ID?) -> Bool {
        guard let id else { return false }

        // Parent row is synthetic and may have different instances/IDs
        if isParentRow(file) {
            return cachedSortedRows.first(where: { isParentRow($0) })?.id == id
        }

        return file.id == id
    }

    /// Current selected file ID from AppState (source of truth for keyboard navigation).
    /// For the synthetic parent-navigation row, map AppState selection to the visible row ID
    /// from cachedSortedRows, because the visible parent row may be recreated with its own ID.
    private var selectedFileIDFromState: CustomFile.ID? {
        guard let selected = appState.panel(panelSide).selectedFile else {
            return nil
        }

        // Map synthetic parent entry ("..") from AppState to the visible row instance
        if isParentRow(selected) {
            return cachedSortedRows.first(where: { isParentRow($0) })?.id
        }

        return selected.id
    }

    // Note: for the parent row (".."), newID already refers to the visible row id
    // produced by `selectedFileIDFromState` mapping above.
    private func updateSelectedIndex(for newID: CustomFile.ID?) {
        if let id = newID,
            let rowIndex = cachedSortedRows.firstIndex(where: { $0.id == id })
        {
            appState.setSelectedIndex(rowIndex, for: panelSide)
        } else {
            appState.setSelectedIndex(0, for: panelSide)
        }
    }

    private func onAppear() {
        log.debug("[FileTableView] appear panel=\(panelSide) files=\(files.count)")
        log.debug("[Columns] panel=\(panelSide) column count=\(layout.columns.count)")
        recomputeSortedCache()
        registerNavigationCallbacks()
    }

    private func handleSelectionChange(_ newID: CustomFile.ID?) {
        updateSelectedIndex(for: newID)
    }

    private func syncSelectionFromState(_ newID: CustomFile.ID?) {
        if selectedID != newID {
            selectedID = newID
        }
    }

    private func handleLoadingChange(_ loading: Bool) {
        spinnerTask?.cancel()

        if loading {
            spinnerTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 150_000_000)
                if !Task.isCancelled && isLoading {
                    showSpinner = true
                }
            }
        } else {
            showSpinner = false
        }
    }

    private func handleUpArrow() -> KeyPress.Result {
        guard isFocused else { return KeyPress.Result.ignored }
        keyboardNav.moveUp()
        return KeyPress.Result.handled
    }

    private func handleDownArrow() -> KeyPress.Result {
        guard isFocused else { return KeyPress.Result.ignored }
        keyboardNav.moveDown()
        return KeyPress.Result.handled
    }

    private func handlePageUp() -> KeyPress.Result {
        guard isFocused else { return KeyPress.Result.ignored }
        if pageNavThrottle.allow() {
            keyboardNav.pageUp()
        }
        return KeyPress.Result.handled
    }

    private func handlePageDown() -> KeyPress.Result {
        guard isFocused else { return KeyPress.Result.ignored }
        if pageNavThrottle.allow() {
            keyboardNav.pageDown()
        }
        return KeyPress.Result.handled
    }

    private func handleHome() -> KeyPress.Result {
        guard isFocused else { return KeyPress.Result.ignored }
        keyboardNav.jumpToFirst()
        return KeyPress.Result.handled
    }

    private func handleEnd() -> KeyPress.Result {
        guard isFocused else { return KeyPress.Result.ignored }
        keyboardNav.jumpToLast()
        return KeyPress.Result.handled
    }

    private func handleFilesVersionChange(_: Int) {
        log.debug("[FileTableView] filesVersion changed panel=\(panelSide) new=\(filesVersion) files=\(files.count)")
        recomputeSortedCache()
        scheduleAutoFitIfNeeded()
    }

    // MARK: - Deferred AutoFit: wait for background sizes, then fit

    /// True when every directory in current panel has a resolved size.
    /// Reads live from appState (not captured `files` snapshot).
    private var allSizesResolved: Bool {
        let liveFiles = appState.displayedFiles(for: panelSide)
        return liveFiles.allSatisfy { file in
            guard file.isDirectory else { return true }
            if file.sizeIsExact { return true }
            if file.securityState == .restricted { return true }
            if file.cachedDirectorySize != nil { return true }
            return false
        }
    }

    /// Schedule a deferred autofit that waits until all dir sizes are resolved.
    /// Cancels any previously pending autofit (new navigation supersedes old).
    /// Runs up to 3 passes with ~2s delay between them for progressive refinement.
    private func scheduleAutoFitIfNeeded() {
        guard UserPreferences.shared.snapshot.autoFitColumnsOnNavigate else { return }
        let currentPath = appState.path(for: panelSide)
        // Already running or completed for this path — skip
        guard currentPath != lastAutoFitPath else { return }
        // Cancel previous task if navigated to a new dir before it finished
        if let existing = pendingAutoFitTask, !existing.isCancelled {
            existing.cancel()
        }
        // Mark path immediately to prevent re-entry from subsequent bumps
        lastAutoFitPath = currentPath
        pendingAutoFitTask = Task { @MainActor in
            // pass 1: wait until all sizes resolved (poll every 500ms, max 30s)
            for _ in 0..<60 {
                if Task.isCancelled { return }
                if allSizesResolved { break }
                try? await Task.sleep(for: .milliseconds(500))
            }
            if Task.isCancelled { return }
            let liveFiles = appState.displayedFiles(for: panelSide)
            lastAutoFitWidth = layout.containerWidth
            ColumnAutoFitter.autoFitAll(layout: layout, files: liveFiles)
            // pass 2: re-fit after 2s (late arrivals, app bundle sizes)
            try? await Task.sleep(for: .seconds(2))
            if Task.isCancelled { return }
            ColumnAutoFitter.autoFitAll(layout: layout, files: appState.displayedFiles(for: panelSide))
            // pass 3: final re-fit after another 2s (very slow dirs)
            try? await Task.sleep(for: .seconds(2))
            if Task.isCancelled { return }
            ColumnAutoFitter.autoFitAll(layout: layout, files: appState.displayedFiles(for: panelSide))
        }
    }

    /// Re-fit columns when panel width changes.
    /// Small jitter (<8pt) is ignored to avoid layout thrash.
    private func handleContainerWidthChange(_ newWidth: CGFloat) {
        guard UserPreferences.shared.snapshot.autoFitColumnsOnNavigate else { return }
        let liveFiles = appState.displayedFiles(for: panelSide)
        guard !liveFiles.isEmpty else { return }
        let delta = abs(newWidth - lastAutoFitWidth)
        guard delta > 8 else { return }
        lastAutoFitWidth = newWidth
        ColumnAutoFitter.autoFitAll(layout: layout, files: liveFiles)
    }

    private func handleSortChange<T>(_: T) {
        recomputeSortedCacheForSortChange()
    }

    private func handleEscape() -> KeyPress.Result {
        guard isFocused else { return KeyPress.Result.ignored }

        let markedCount = appState.markedCount(for: panelSide)
        if markedCount > 0 {
            appState.unmarkAll()
        }

        appState.ensureSelectionOnFocusedPanel()
        return KeyPress.Result.handled
    }

    private var jumpToFirstPublisher: AnyPublisher<Notification, Never> {
        NotificationCenter.default.publisher(for: .jumpToFirst)
            .filter { ($0.object as? FavPanelSide) == panelSide }
            .eraseToAnyPublisher()
    }

    private var jumpToLastPublisher: AnyPublisher<Notification, Never> {
        NotificationCenter.default.publisher(for: .jumpToLast)
            .filter { ($0.object as? FavPanelSide) == panelSide }
            .eraseToAnyPublisher()
    }

    private func handleJumpToFirst(_: Notification) {
        keyboardNav.jumpToFirst()
    }

    private func handleJumpToLast(_: Notification) {
        keyboardNav.jumpToLast()
    }

}
