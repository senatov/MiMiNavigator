// AppState.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 28.05.2025.
// Copyright © 2025-2026 Senatov. All rights reserved.
// Description: Central application state — properties and init only.
//   Extracted to: +Navigation, +Refresh, +Archive, +Marks

import AppKit
import FileModelKit
import Foundation

@MainActor
@Observable
final class AppState {

    // MARK: - Version Counters
    private(set) var leftFilesVersion: Int = 0
    private(set) var rightFilesVersion: Int = 0
    var displayedLeftFiles: [CustomFile] = [] { didSet { leftFilesVersion &+= 1 } }
    var displayedRightFiles: [CustomFile] = [] { didSet { rightFilesVersion &+= 1 } }
    var focusedPanel: PanelSide = .left

    // MARK: - Filter
    var leftFilterQuery: String = ""
    var rightFilterQuery: String = ""

    // MARK: - Paths
    var leftPath: String
    var rightPath: String
    var savedLocalLeftPath: String?
    var savedLocalRightPath: String?

    // MARK: - UI State
    var selectedDir: DirectorySelection = .init()
    var showFavTreePopup: Bool = false
    var showNetworkNeighborhood: Bool = false

    // MARK: - Archive State (per-panel)
    var leftArchiveState = ArchiveNavigationState()
    var rightArchiveState = ArchiveNavigationState()
    var navigationCallbacks: [PanelSide: PanelNavigationCallbacks] = [:]

    // MARK: - Search Results
    var leftSearchResultsPath: String?
    var rightSearchResultsPath: String?
    var searchResultArchives: [PanelSide: Set<String>] = [:]

    // MARK: - Sorting
    var sortKey: SortKeysEnum = .name
    var bSortAscending: Bool = true

    // MARK: - Flags
    var isNavigatingFromHistory = false
    var navigatingPanel: PanelSide? = nil

    // MARK: - Selection
    var selectedLeftFile: CustomFile? {
        didSet { selectionManager?.recordSelection(.left, file: selectedLeftFile) }
    }
    var selectedRightFile: CustomFile? {
        didSet { selectionManager?.recordSelection(.right, file: selectedRightFile) }
    }

    // MARK: - Marks
    var markedLeftFiles: Set<String> = []
    var markedRightFiles: Set<String> = []

    // MARK: - Index tracking
    var leftSelectedIndex: Int = 0
    var rightSelectedIndex: Int = 0
    var leftVisibleIndex: Int = 0
    var rightVisibleIndex: Int = 0

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
        self.leftPath = paths.left
        self.rightPath = paths.right
        self.focusedPanel = StatePersistence.loadInitialFocus()

        if let storedKey = UserDefaults.standard.string(forKey: "MiMiNavigator.sortKey"),
           let key = SortKeysEnum(rawValue: storedKey) {
            self.sortKey = key
        }
        if UserDefaults.standard.object(forKey: "MiMiNavigator.sortAscending") != nil {
            self.bSortAscending = UserDefaults.standard.bool(forKey: "MiMiNavigator.sortAscending")
        }

        self.leftTabManager = TabManager(panelSide: .left, initialPath: paths.left)
        self.rightTabManager = TabManager(panelSide: .right, initialPath: paths.right)
        self.leftNavigationHistory = PanelNavigationHistory(panel: .left)
        self.rightNavigationHistory = PanelNavigationHistory(panel: .right)

        if leftNavigationHistory.currentPath == nil { leftNavigationHistory.navigateTo(paths.left) }
        if rightNavigationHistory.currentPath == nil { rightNavigationHistory.navigateTo(paths.right) }

        self.selectionManager = SelectionManager(appState: self, history: selectionsHistory)
        self.multiSelectionManager = MultiSelectionManager(appState: self)
        self.fileActions = FileOperationActions(appState: self)
        self.scanner = DualDirectoryScanner(appState: self)
    }

    // MARK: - Helpers
    func firstRealFile(_ files: [CustomFile]) -> CustomFile? { files.first { !$0.isParentEntry } }
    func selectedIndex(for p: PanelSide) -> Int { p == .left ? leftSelectedIndex : rightSelectedIndex }
    func visibleIndex(for p: PanelSide) -> Int { p == .left ? leftVisibleIndex : rightVisibleIndex }
    func setSelectedIndex(_ i: Int, for p: PanelSide) { if p == .left { leftSelectedIndex = i } else { rightSelectedIndex = i } }
    func setVisibleIndex(_ i: Int, for p: PanelSide) { if p == .left { leftVisibleIndex = i } else { rightVisibleIndex = i } }
}
