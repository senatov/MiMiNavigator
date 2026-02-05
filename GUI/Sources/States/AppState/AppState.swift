// AppState.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 28.05.2025.
// Refactored: 27.01.2026
// Copyright © 2025-2026 Senatov. All rights reserved.
// Description: Central application state - coordinates sub-managers

import AppKit
import Foundation

// MARK: - App State
/// Central observable state for the dual-panel file manager
@MainActor
@Observable
final class AppState {

    // MARK: - Observable State
    var displayedLeftFiles: [CustomFile] = []
    var displayedRightFiles: [CustomFile] = []
    var focusedPanel: PanelSide = .left
    var leftPath: String
    var rightPath: String
    var selectedDir: DirectorySelection = .init()
    var showFavTreePopup: Bool = false
    var sortKey: SortKeysEnum = .name
    var sortAscending: Bool = true

    var selectedLeftFile: CustomFile? {
        didSet { selectionManager?.recordSelection(.left, file: selectedLeftFile) }
    }
    var selectedRightFile: CustomFile? {
        didSet { selectionManager?.recordSelection(.right, file: selectedRightFile) }
    }

    // MARK: - Multi-Selection State (Total Commander style marking)
    var markedLeftFiles: Set<String> = []
    var markedRightFiles: Set<String> = []

    // MARK: - Sub-managers (lazy initialized)
    private(set) var selectionManager: SelectionManager?
    private(set) var multiSelectionManager: MultiSelectionManager?
    private(set) var fileActions: FileOperationActions?
    let selectionsHistory = SelectionsHistory()
    var scanner: DualDirectoryScanner!

    // MARK: - Initialization
    init() {
        log.info("[AppState] init")

        let paths = StatePersistence.loadInitialPaths()
        self.leftPath = paths.left
        self.rightPath = paths.right
        self.focusedPanel = StatePersistence.loadInitialFocus()

        // Initialize sub-managers
        self.selectionManager = SelectionManager(appState: self, history: selectionsHistory)
        self.multiSelectionManager = MultiSelectionManager(appState: self)
        self.fileActions = FileOperationActions(appState: self)
        self.scanner = DualDirectoryScanner(appState: self)

        log.debug("[AppState] paths: L=\(leftPath) R=\(rightPath) focus=\(focusedPanel)")
    }
}

// MARK: - Selection Operations
extension AppState {

    func select(_ file: CustomFile, on panelSide: PanelSide) {
        selectionManager?.select(file, on: panelSide)
    }

    func clearSelection(on panelSide: PanelSide) {
        selectionManager?.clearSelection(on: panelSide)
    }

    func toggleFocus() {
        selectionManager?.toggleFocus()
    }

    func selectionMove(by step: Int) {
        selectionManager?.moveSelection(by: step)
    }
}

// MARK: - Multi-Selection Operations (Total Commander style)
extension AppState {

    /// Toggle mark on current file and move to next (Insert key)
    func toggleMarkAndMoveNext() {
        multiSelectionManager?.toggleMarkAndMoveNext()
    }

    /// Mark files by pattern (Num+)
    func markByPattern() {
        multiSelectionManager?.markByPattern(shouldMark: true)
    }

    /// Unmark files by pattern (Num-)
    func unmarkByPattern() {
        multiSelectionManager?.markByPattern(shouldMark: false)
    }

    /// Mark all files (Ctrl+A)
    func markAll() {
        multiSelectionManager?.markAll()
    }

    /// Unmark all files
    func unmarkAll() {
        multiSelectionManager?.unmarkAll()
    }

    /// Invert marks (Num*)
    func invertMarks() {
        multiSelectionManager?.invertMarks()
    }

    /// Mark files with same extension as current
    func markSameExtension() {
        multiSelectionManager?.markSameExtension()
    }

    /// Clear marks after successful operation
    func clearMarksAfterOperation(on panel: PanelSide) {
        multiSelectionManager?.clearMarksAfterOperation(on: panel)
    }
}

// MARK: - File Operations
extension AppState {

    func selectionCopy() {
        fileActions?.copyToOppositePanel()
    }

    func openSelectedItem() {
        fileActions?.openSelectedItem()
    }

    func revealLogFileInFinder() {
        FinderIntegration.revealLogFile()
    }
}

// MARK: - Data Access
extension AppState {

    func displayedFiles(for panelSide: PanelSide) -> [CustomFile] {
        switch panelSide {
            case .left: return displayedLeftFiles
            case .right: return displayedRightFiles
        }
    }

    func pathURL(for panelSide: PanelSide) -> URL? {
        let path = panelSide == .left ? leftPath : rightPath
        return URL(fileURLWithPath: path)
    }
}

// MARK: - Sorting
extension AppState {

    func updateSorting(key: SortKeysEnum? = nil, ascending: Bool? = nil) {
        if let newKey = key { sortKey = newKey }
        if let newAsc = ascending { sortAscending = newAsc }

        log.debug("[AppState] updateSorting key=\(sortKey) asc=\(sortAscending) panel=\(focusedPanel)")

        if focusedPanel == .left {
            displayedLeftFiles = FileSortingService.sort(displayedLeftFiles, by: sortKey, ascending: sortAscending)
        } else {
            displayedRightFiles = FileSortingService.sort(displayedRightFiles, by: sortKey, ascending: sortAscending)
        }
    }

    func applySorting(_ items: [CustomFile]) -> [CustomFile] {
        FileSortingService.sort(items, by: sortKey, ascending: sortAscending)
    }
}

// MARK: - Path Updates
extension AppState {

    func updatePath(_ path: String, for panelSide: PanelSide) {
        let currentPath = panelSide == .left ? leftPath : rightPath

        guard !PathUtils.areEqual(currentPath, path) else {
            log.debug("[AppState] path unchanged: \(path)")
            return
        }

        log.debug("[AppState] updatePath \(panelSide) → \(path)")
        focusedPanel = panelSide

        switch panelSide {
            case .left:
                leftPath = path
                selectedLeftFile = displayedLeftFiles.first
            case .right:
                rightPath = path
                selectedRightFile = displayedRightFiles.first
        }
    }
}

// MARK: - Refresh Operations
extension AppState {

    @Sendable
    func refreshFiles() async {
        log.debug("[AppState] refreshFiles (both)")
        await refreshLeftFiles()
        await refreshRightFiles()
    }

    func refreshLeftFiles() async {
        log.debug("[AppState] refreshLeftFiles path=\(leftPath)")
        await scanner.refreshFiles(currSide: .left)

        if focusedPanel == .left, selectedLeftFile == nil {
            selectedLeftFile = displayedLeftFiles.first
            if let f = selectedLeftFile {
                log.debug("[AppState] auto-selected L: \(f.nameStr)")
            }
        }
    }

    func refreshRightFiles() async {
        log.debug("[AppState] refreshRightFiles path=\(rightPath)")
        await scanner.refreshFiles(currSide: .right)

        if focusedPanel == .right, selectedRightFile == nil {
            selectedRightFile = displayedRightFiles.first
            if let f = selectedRightFile {
                log.debug("[AppState] auto-selected R: \(f.nameStr)")
            }
        }
    }
}

// MARK: - Settings
extension AppState {

    func toggleShowHiddenFiles() {
        UserPreferences.shared.snapshot.showHiddenFiles.toggle()
        let newValue = UserPreferences.shared.snapshot.showHiddenFiles
        log.info("[AppState] showHiddenFiles toggled to \(newValue)")

        Task {
            await scanner.refreshFiles(currSide: .left)
            await scanner.refreshFiles(currSide: .right)
        }
    }

    func forceRefreshBothPanels() {
        log.debug("[AppState] forceRefreshBothPanels")
        Task {
            await scanner.refreshFiles(currSide: .left)
            await scanner.refreshFiles(currSide: .right)
        }
    }
}

// MARK: - Lifecycle
extension AppState {

    func initialize() {
        log.debug("[AppState] initialize")
        UserPreferences.shared.load()
        UserPreferences.shared.apply(to: self)

        Task {
            await scanner.setLeftDirectory(pathStr: leftPath)
            await refreshLeftFiles()
            await scanner.setRightDirectory(pathStr: rightPath)
            await refreshRightFiles()
            selectionManager?.restoreSelectionsAndFocus()
            await scanner.startMonitoring()
            log.info("[AppState] initialization complete")
        }
    }

    func saveBeforeExit() {
        StatePersistence.saveBeforeExit(from: self)
    }
}
