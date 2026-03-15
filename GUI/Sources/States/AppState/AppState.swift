// AppState.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 28.05.2025.
// Copyright © 2025-2026 Senatov. All rights reserved.
// Description: Central application state — properties and init only.
//   Per-panel state lives in PanelState. AppState provides unified accessors.
//   Extracted to: +Navigation, +Refresh, +Archive, +Marks, +Selection,
//   +KeyboardNav, +FileActivation, +DataAccess, +Sorting, +Lifecycle,
//   +SearchResults, +Settings

import AppKit
import FileModelKit
import Foundation

// MARK: - AppState
@MainActor
@Observable
final class AppState {

    var leftPanel: PanelState
    var rightPanel: PanelState
    var focusedPanel: PanelSide = .left

    // MARK: - Displayed files (primary storage with version tracking)
    var displayedLeftFiles: [CustomFile] = [] { didSet { leftPanel.filesVersion &+= 1 } }
    var displayedRightFiles: [CustomFile] = [] { didSet { rightPanel.filesVersion &+= 1 } }

    // MARK: - Version counters (bridge to PanelState)
    var leftFilesVersion: Int { leftPanel.filesVersion }
    var rightFilesVersion: Int { rightPanel.filesVersion }

    // MARK: - Filter (bridge)
    var leftFilterQuery: String {
        get { leftPanel.filterQuery }
        set { leftPanel.filterQuery = newValue }
    }
    var rightFilterQuery: String {
        get { rightPanel.filterQuery }
        set { rightPanel.filterQuery = newValue }
    }

    // MARK: - Paths (bridge)
    var leftURL: URL {
        get { leftPanel.currentDirectory }
        set { leftPanel.currentDirectory = newValue }
    }
    var rightURL: URL {
        get { rightPanel.currentDirectory }
        set { rightPanel.currentDirectory = newValue }
    }
    var savedLocalLeftURL: URL? {
        get { leftPanel.savedLocalURL }
        set { leftPanel.savedLocalURL = newValue }
    }
    var savedLocalRightURL: URL? {
        get { rightPanel.savedLocalURL }
        set { rightPanel.savedLocalURL = newValue }
    }
    var leftPath: String {
        get { leftURL.path }
        set { leftURL = URL(fileURLWithPath: newValue) }
    }
    var rightPath: String {
        get { rightURL.path }
        set { rightURL = URL(fileURLWithPath: newValue) }
    }
    var savedLocalLeftPath: String? {
        get { savedLocalLeftURL?.path }
        set { savedLocalLeftURL = newValue.map { URL(fileURLWithPath: $0) } }
    }
    var savedLocalRightPath: String? {
        get { savedLocalRightURL?.path }
        set { savedLocalRightURL = newValue.map { URL(fileURLWithPath: $0) } }
    }

    func url(for panel: PanelSide) -> URL {
        panel == .left ? leftURL : rightURL
    }

    func path(for panel: PanelSide) -> String {
        panel == .left ? leftPath : rightPath
    }

    func setPath(_ path: String, for panel: PanelSide) {
        log.debug(#function + " for \(panel): \(path)")
        if panel == .left {
            leftURL = URL(fileURLWithPath: path)
        } else {
            rightURL = URL(fileURLWithPath: path)
        }
    }

    func setURL(_ url: URL, for panel: PanelSide) {
        do {
            let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey])
            if values.isDirectory != true {
                log.error("[AppState] Attempt to set panel path to non-directory: \(url.path)")
                return
            }
        } catch {
            log.error("[AppState] Failed to inspect URL: \(url.path) error=\(error.localizedDescription)")
            return
        }
        if panel == .left { leftURL = url } else { rightURL = url }
    }

    // MARK: - UI State
    var selectedDir: DirectorySelection = .init()
    var showFavTreePopup: Bool = false
    var showNetworkNeighborhood: Bool = false

    // MARK: - Archive State (bridge)
    var leftArchiveState: ArchiveNavigationState {
        get { leftPanel.archiveState }
        set { leftPanel.archiveState = newValue }
    }
    var rightArchiveState: ArchiveNavigationState {
        get { rightPanel.archiveState }
        set { rightPanel.archiveState = newValue }
    }
    var navigationCallbacks: [PanelSide: PanelNavigationCallbacks] = [:]

    // MARK: - Search Results (bridge)
    var leftSearchResultsPath: String? {
        get { leftPanel.searchResultsPath }
        set { leftPanel.searchResultsPath = newValue }
    }
    var rightSearchResultsPath: String? {
        get { rightPanel.searchResultsPath }
        set { rightPanel.searchResultsPath = newValue }
    }
    var searchResultArchives: [PanelSide: Set<String>] = [:]

    // MARK: - Sorting
    var sortKey: SortKeysEnum = .name
    var bSortAscending: Bool = true

    // MARK: - Flags
    var isNavigatingFromHistory = false
    var navigatingPanel: PanelSide? = nil

    // MARK: - Selection (bridge)
    var selectedLeftFile: CustomFile? {
        get { leftPanel.selectedFile }
        set {
            leftPanel.selectedFile = newValue
            selectionManager?.recordSelection(.left, file: newValue)
        }
    }
    var selectedRightFile: CustomFile? {
        get { rightPanel.selectedFile }
        set {
            rightPanel.selectedFile = newValue
            selectionManager?.recordSelection(.right, file: newValue)
        }
    }

    // MARK: - Marks (bridge)
    var markedLeftFiles: Set<String> {
        get { leftPanel.markedFiles }
        set { leftPanel.markedFiles = newValue }
    }
    var markedRightFiles: Set<String> {
        get { rightPanel.markedFiles }
        set { rightPanel.markedFiles = newValue }
    }

    // MARK: - Index tracking (bridge)
    var leftSelectedIndex: Int {
        get { leftPanel.selectedIndex }
        set { leftPanel.selectedIndex = newValue }
    }
    var rightSelectedIndex: Int {
        get { rightPanel.selectedIndex }
        set { rightPanel.selectedIndex = newValue }
    }
    var leftVisibleIndex: Int {
        get { leftPanel.visibleIndex }
        set { leftPanel.visibleIndex = newValue }
    }
    var rightVisibleIndex: Int {
        get { rightPanel.visibleIndex }
        set { rightPanel.visibleIndex = newValue }
    }

    // MARK: - Tab Managers
    private(set) var leftTabManager: TabManager!
    private(set) var rightTabManager: TabManager!

    // MARK: - Sub-managers
    private(set) var selectionManager: SelectionManager?
    private(set) var multiSelectionManager: MultiSelectionManager?
    private(set) var fileActions: FileOperationActions?
    let selectionsHistory = SelectionsHistory()
    var scanner: DualDirectoryScanner!
    private(set) var leftNavigationHistory: PanelNavigationHistory!
    private(set) var rightNavigationHistory: PanelNavigationHistory!

    // MARK: - Init
    init() {
        log.info("[AppState] init")
        let paths = StatePersistence.loadInitialPaths()
        leftPanel = PanelState(currentDirectory: paths.left)
        rightPanel = PanelState(currentDirectory: paths.right)
        self.focusedPanel = StatePersistence.loadInitialFocus()
        if let storedKey = UserDefaults.standard.string(forKey: "MiMiNavigator.sortKey"),
           let key = SortKeysEnum(rawValue: storedKey) {
            self.sortKey = key
        }
        if UserDefaults.standard.object(forKey: "MiMiNavigator.sortAscending") != nil {
            self.bSortAscending = UserDefaults.standard.bool(forKey: "MiMiNavigator.sortAscending")
        }
        self.leftTabManager = TabManager(panelSide: .left, initialURL: leftURL)
        self.rightTabManager = TabManager(panelSide: .right, initialURL: rightURL)
        self.leftNavigationHistory = PanelNavigationHistory(panel: .left)
        self.rightNavigationHistory = PanelNavigationHistory(panel: .right)
        if leftNavigationHistory.currentPath == nil { leftNavigationHistory.navigateTo(leftURL) }
        if rightNavigationHistory.currentPath == nil { rightNavigationHistory.navigateTo(rightURL) }
        self.selectionManager = SelectionManager(appState: self, history: selectionsHistory)
        self.multiSelectionManager = MultiSelectionManager(appState: self)
        self.fileActions = FileOperationActions(appState: self)
        self.scanner = DualDirectoryScanner(appState: self)
    }

    // MARK: - Helpers
    func firstRealFile(in files: [CustomFile]) -> CustomFile? {
        files.first { !$0.isParentEntry }
    }

    func setSelectedFile(_ file: CustomFile?, for panel: PanelSide) {
        if panel == .left { selectedLeftFile = file } else { selectedRightFile = file }
    }

    func selectedIndex(for panel: PanelSide) -> Int {
        panel == .left ? leftSelectedIndex : rightSelectedIndex
    }

    func visibleIndex(for panel: PanelSide) -> Int {
        panel == .left ? leftVisibleIndex : rightVisibleIndex
    }

    func setSelectedIndex(_ index: Int, for panel: PanelSide) {
        if panel == .left { leftSelectedIndex = index } else { rightSelectedIndex = index }
    }

    func setVisibleIndex(_ index: Int, for panel: PanelSide) {
        if panel == .left { leftVisibleIndex = index } else { rightVisibleIndex = index }
    }
}

// MARK: - Panel Access
extension AppState {

    func panel(_ side: PanelSide) -> PanelState {
        side == .left ? leftPanel : rightPanel
    }

    subscript(panel side: PanelSide) -> PanelState {
        get { side == .left ? leftPanel : rightPanel }
        set {
            if side == .left { leftPanel = newValue } else { rightPanel = newValue }
        }
    }
}
