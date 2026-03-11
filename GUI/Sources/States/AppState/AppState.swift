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

    // Temporary simple navigation history implementation
    final class NavigationHistory {
        private(set) var current: URL?

        func navigate(to url: URL) {
            current = url
        }
    }

    /// Central application state for MiMiNavigator.
    /// Owns panel paths, file lists, selection state and navigation managers.
    /// Marked @MainActor because it is directly consumed by SwiftUI views.
    @MainActor
    @Observable
    final class AppState {

        var leftPanel: PanelState
        var rightPanel: PanelState

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
        /// Canonical filesystem paths for panels (kept as String for compatibility with existing code)
        var leftPath: String
        var rightPath: String
        var savedLocalLeftPath: String?
        var savedLocalRightPath: String?

        /// URL helpers (preferred API for new code)
        var leftURL: URL { URL(fileURLWithPath: leftPath) }
        var rightURL: URL { URL(fileURLWithPath: rightPath) }

        func url(for panel: PanelSide) -> URL {
            panel == .left ? leftURL : rightURL
        }

        func path(for panel: PanelSide) -> String {
            panel == .left ? leftPath : rightPath
        }

        func setPath(_ path: String, for panel: PanelSide) {
            if panel == .left {
                leftPath = path
            } else {
                rightPath = path
            }
        }

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
            leftPanel = PanelState(
                currentDirectory: URL(fileURLWithPath: paths.left),
                navigationHistory: NavigationHistory()
            )

            rightPanel = PanelState(
                currentDirectory: URL(fileURLWithPath: paths.right),
                navigationHistory: NavigationHistory()
            )

            self.leftPath = paths.left
            self.rightPath = paths.right
            self.focusedPanel = StatePersistence.loadInitialFocus()

            if let storedKey = UserDefaults.standard.string(forKey: "MiMiNavigator.sortKey"),
                let key = SortKeysEnum(rawValue: storedKey)
            {
                self.sortKey = key
            }
            if UserDefaults.standard.object(forKey: "MiMiNavigator.sortAscending") != nil {
                self.bSortAscending = UserDefaults.standard.bool(forKey: "MiMiNavigator.sortAscending")
            }

            self.leftTabManager = TabManager(panelSide: .left, initialPath: paths.left)
            self.rightTabManager = TabManager(panelSide: .right, initialPath: paths.right)
            self.leftNavigationHistory = PanelNavigationHistory(panel: .left)
            self.rightNavigationHistory = PanelNavigationHistory(panel: .right)

            if leftNavigationHistory.currentPath == nil { leftNavigationHistory.navigateTo(URL(fileURLWithPath: paths.left)) }
            if rightNavigationHistory.currentPath == nil { rightNavigationHistory.navigateTo(URL(fileURLWithPath: paths.right)) }

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
            if panel == .left {
                selectedLeftFile = file
            } else {
                selectedRightFile = file
            }
        }

        func selectedIndex(for panel: PanelSide) -> Int {
            panel == .left ? leftSelectedIndex : rightSelectedIndex
        }

        func visibleIndex(for panel: PanelSide) -> Int {
            panel == .left ? leftVisibleIndex : rightVisibleIndex
        }

        func setSelectedIndex(_ index: Int, for panel: PanelSide) {
            switch panel {
                case .left:
                    leftSelectedIndex = index
                case .right:
                    rightSelectedIndex = index
            }
        }

        func setVisibleIndex(_ index: Int, for panel: PanelSide) {
            switch panel {
                case .left:
                    leftVisibleIndex = index
                case .right:
                    rightVisibleIndex = index
            }
        }
    }

    extension AppState {

        func panel(_ side: PanelSide) -> PanelState {
            side == .left ? leftPanel : rightPanel
        }

        subscript(panel side: PanelSide) -> PanelState {
            get {
                side == .left ? leftPanel : rightPanel
            }
            set {
                if side == .left {
                    leftPanel = newValue
                } else {
                    rightPanel = newValue
                }
            }
        }
    }
