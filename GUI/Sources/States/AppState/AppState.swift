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
    var focusedPanel: FavPanelSide = .left

    // MARK: - Displayed files (primary storage with version tracking)
    var displayedLeftFiles: [CustomFile] = [] { didSet { leftPanel.filesVersion &+= 1 } }
    var displayedRightFiles: [CustomFile] = [] { didSet { rightPanel.filesVersion &+= 1 } }

    // MARK: - Version counters (bridge to PanelState)
    var leftFilesVersion: Int { leftPanel.filesVersion }
    var rightFilesVersion: Int { rightPanel.filesVersion }

    /// Bump version without replacing the file array — triggers onChange observers.
    /// Use when in-place mutations (e.g. deferred directory sizes) need to re-trigger autofit.
    func bumpFilesVersion(for panel: FavPanelSide) {
        if panel == .left { leftPanel.filesVersion &+= 1 } else { rightPanel.filesVersion &+= 1 }
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
    // MARK: - UI State
    var selectedDir: DirectorySelection = .init()
    var showFavTreePopup: Bool = false
    var showNetworkNeighborhood: Bool = false
    var isTerminating: Bool = false

    // MARK: - Loading State
    /// Explicit loading flags for panels (used by UI instead of guessing from scanner)
    var isLeftLoading: Bool = false
    var isRightLoading: Bool = false

    func isLoading(_ side: FavPanelSide) -> Bool {
        side == .left ? isLeftLoading : isRightLoading
    }

    func setLoading(_ side: FavPanelSide, _ value: Bool) {
        if side == .left {
            isLeftLoading = value
        } else {
            isRightLoading = value
        }
    }

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

    func url(for panel: FavPanelSide) -> URL {
        switch panel {
            case .left: return leftURL
            case .right: return rightURL
        }
    }

    func path(for panel: FavPanelSide) -> String {
        switch panel {
            case .left: return leftPath
            case .right: return rightPath
        }
    }

    func setPath(_ path: String, for panel: FavPanelSide) {
        log.debug("[AppState] setPath panel=\(panel) path=\(path)")
        if panel == .left {
            leftURL = URL(fileURLWithPath: path)
        } else {
            rightURL = URL(fileURLWithPath: path)
        }
    }

    func beginTermination() {
        guard !isTerminating else { return }
        isTerminating = true
        log.info("[AppState] beginTermination")
    }

    // MARK: - Init
    init() {
        log.info("[AppState] init")
        let paths = StatePersistence.loadInitialPaths()
        leftPanel = PanelState(currentDirectory: paths.left)
        rightPanel = PanelState(currentDirectory: paths.right)
        self.focusedPanel = StatePersistence.loadInitialFocus()
        if let storedKey = MiMiDefaults.shared.string(forKey: "MiMiNavigator.sortKey"),
            let key = SortKeysEnum(rawValue: storedKey)
        {
            self.sortKey = key
        }
        if MiMiDefaults.shared.object(forKey: "MiMiNavigator.sortAscending") != nil {
            self.bSortAscending = MiMiDefaults.shared.bool(forKey: "MiMiNavigator.sortAscending")
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
        applyPreferencesFromSnapshot()
    }

    func setURL(_ url: URL, for panel: FavPanelSide) {
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
        if panel == .left {
            leftURL = url
        } else {
            rightURL = url
        }
    }

    // MARK: - Archive State (bridge)
    var leftArchiveState: ArchiveNavigationState {
        get { leftPanel.archiveState }
        set { leftPanel.archiveState = newValue }
    }
    var rightArchiveState: ArchiveNavigationState {
        get { rightPanel.archiveState }
        set { rightPanel.archiveState = newValue }
    }
    var navigationCallbacks: [FavPanelSide: PanelNavigationCallbacks] = [:]

    // MARK: - Search Results (bridge)
    var leftSearchResultsPath: String? {
        get { leftPanel.searchResultsPath }
        set { leftPanel.searchResultsPath = newValue }
    }
    var rightSearchResultsPath: String? {
        get { rightPanel.searchResultsPath }
        set { rightPanel.searchResultsPath = newValue }
    }
    var searchResultArchives: [FavPanelSide: Set<String>] = [:]

    // MARK: - Sorting
    var sortKey: SortKeysEnum = .name
    var bSortAscending: Bool = true

    // MARK: - User Preference Flags
    private var suppressPreferencesWriteback = false

    var showHiddenFiles: Bool = UserPreferences.shared.snapshot.showHiddenFiles {
        didSet { persistPreferenceChange { $0.showHiddenFiles = showHiddenFiles } }
    }
    var showExtensions: Bool = UserPreferences.shared.snapshot.showExtensions {
        didSet { persistPreferenceChange { $0.showExtensions = showExtensions } }
    }
    var autoFitColumnsOnNavigate: Bool = UserPreferences.shared.snapshot.autoFitColumnsOnNavigate {
        didSet { persistPreferenceChange { $0.autoFitColumnsOnNavigate = autoFitColumnsOnNavigate } }
    }
    var showIcons: Bool = UserPreferences.shared.snapshot.showIcons {
        didSet { persistPreferenceChange { $0.showIcons = showIcons } }
    }
    var calculateSizes: Bool = UserPreferences.shared.snapshot.calculateSizes {
        didSet { persistPreferenceChange { $0.calculateSizes = calculateSizes } }
    }
    var highlightBorder: Bool = UserPreferences.shared.snapshot.highlightBorder {
        didSet { persistPreferenceChange { $0.highlightBorder = highlightBorder } }
    }
    var showSizeInKB: Bool = UserPreferences.shared.snapshot.showSizeInKB {
        didSet { persistPreferenceChange { $0.showSizeInKB = showSizeInKB } }
    }
    var openOnSingleClick: Bool = UserPreferences.shared.snapshot.openOnSingleClick {
        didSet { persistPreferenceChange { $0.openOnSingleClick = openOnSingleClick } }
    }
    var tabsRestoreOnLaunch: Bool = UserPreferences.shared.snapshot.tabsRestoreOnLaunch {
        didSet { persistPreferenceChange { $0.tabsRestoreOnLaunch = tabsRestoreOnLaunch } }
    }
    var tabsOpenFolderInNewTab: Bool = UserPreferences.shared.snapshot.tabsOpenFolderInNewTab {
        didSet { persistPreferenceChange { $0.tabsOpenFolderInNewTab = tabsOpenFolderInNewTab } }
    }
    var tabsCloseLastKeepsPanel: Bool = UserPreferences.shared.snapshot.tabsCloseLastKeepsPanel {
        didSet { persistPreferenceChange { $0.tabsCloseLastKeepsPanel = tabsCloseLastKeepsPanel } }
    }
    var tabsShowCloseButton: Bool = UserPreferences.shared.snapshot.tabsShowCloseButton {
        didSet { persistPreferenceChange { $0.tabsShowCloseButton = tabsShowCloseButton } }
    }
    var tabsSortByName: Bool = UserPreferences.shared.snapshot.tabsSortByName {
        didSet { persistPreferenceChange { $0.tabsSortByName = tabsSortByName } }
    }
    var archiveExtractToSubfolder: Bool = UserPreferences.shared.snapshot.archiveExtractToSubfolder {
        didSet { persistPreferenceChange { $0.archiveExtractToSubfolder = archiveExtractToSubfolder } }
    }
    var archiveShowExtractProgress: Bool = UserPreferences.shared.snapshot.archiveShowExtractProgress {
        didSet { persistPreferenceChange { $0.archiveShowExtractProgress = archiveShowExtractProgress } }
    }
    var archiveOpenOnDoubleClick: Bool = UserPreferences.shared.snapshot.archiveOpenOnDoubleClick {
        didSet { persistPreferenceChange { $0.archiveOpenOnDoubleClick = archiveOpenOnDoubleClick } }
    }
    var archiveConfirmOnModified: Bool = UserPreferences.shared.snapshot.archiveConfirmOnModified {
        didSet { persistPreferenceChange { $0.archiveConfirmOnModified = archiveConfirmOnModified } }
    }
    var archiveAutoRepack: Bool = UserPreferences.shared.snapshot.archiveAutoRepack {
        didSet { persistPreferenceChange { $0.archiveAutoRepack = archiveAutoRepack } }
    }
    var networkSavePasswords: Bool = UserPreferences.shared.snapshot.networkSavePasswords {
        didSet { persistPreferenceChange { $0.networkSavePasswords = networkSavePasswords } }
    }
    var networkShowInSidebar: Bool = UserPreferences.shared.snapshot.networkShowInSidebar {
        didSet { persistPreferenceChange { $0.networkShowInSidebar = networkShowInSidebar } }
    }
    var networkAutoReconnect: Bool = UserPreferences.shared.snapshot.networkAutoReconnect {
        didSet { persistPreferenceChange { $0.networkAutoReconnect = networkAutoReconnect } }
    }

    // MARK: - Preference Sync
    func applyPreferencesFromSnapshot() {
        let snapshot = UserPreferences.shared.snapshot
        suppressPreferencesWriteback = true
        showHiddenFiles = snapshot.showHiddenFiles
        showExtensions = snapshot.showExtensions
        autoFitColumnsOnNavigate = snapshot.autoFitColumnsOnNavigate
        showIcons = snapshot.showIcons
        calculateSizes = snapshot.calculateSizes
        highlightBorder = snapshot.highlightBorder
        showSizeInKB = snapshot.showSizeInKB
        openOnSingleClick = snapshot.openOnSingleClick
        tabsRestoreOnLaunch = snapshot.tabsRestoreOnLaunch
        tabsOpenFolderInNewTab = snapshot.tabsOpenFolderInNewTab
        tabsCloseLastKeepsPanel = snapshot.tabsCloseLastKeepsPanel
        tabsShowCloseButton = snapshot.tabsShowCloseButton
        tabsSortByName = snapshot.tabsSortByName
        archiveExtractToSubfolder = snapshot.archiveExtractToSubfolder
        archiveShowExtractProgress = snapshot.archiveShowExtractProgress
        archiveOpenOnDoubleClick = snapshot.archiveOpenOnDoubleClick
        archiveConfirmOnModified = snapshot.archiveConfirmOnModified
        archiveAutoRepack = snapshot.archiveAutoRepack
        networkSavePasswords = snapshot.networkSavePasswords
        networkShowInSidebar = snapshot.networkShowInSidebar
        networkAutoReconnect = snapshot.networkAutoReconnect
        suppressPreferencesWriteback = false
    }

    private func persistPreferenceChange(_ update: (inout PreferencesSnapshot) -> Void) {
        guard !suppressPreferencesWriteback else { return }
        var snapshot = UserPreferences.shared.snapshot
        update(&snapshot)
        UserPreferences.shared.snapshot = snapshot
    }

    // MARK: - Flags
    var isNavigatingFromHistory = false
    var navigatingPanel: FavPanelSide? = nil

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

    // MARK: - Helpers
    func firstRealFile(in files: [CustomFile]) -> CustomFile? {
        files.first { !$0.isParentEntry }
    }

    func setSelectedFile(_ file: CustomFile?, for panel: FavPanelSide) {
        if panel == .left { selectedLeftFile = file } else { selectedRightFile = file }
    }

    func selectedIndex(for panel: FavPanelSide) -> Int {
        panel == .left ? leftSelectedIndex : rightSelectedIndex
    }

    func visibleIndex(for panel: FavPanelSide) -> Int {
        panel == .left ? leftVisibleIndex : rightVisibleIndex
    }

    func setSelectedIndex(_ index: Int, for panel: FavPanelSide) {
        if panel == .left { leftSelectedIndex = index } else { rightSelectedIndex = index }
    }

    func setVisibleIndex(_ index: Int, for panel: FavPanelSide) {
        if panel == .left { leftVisibleIndex = index } else { rightVisibleIndex = index }
    }
}
