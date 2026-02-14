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

    // MARK: - Archive Navigation State (per-panel)
    var leftArchiveState = ArchiveNavigationState()
    var rightArchiveState = ArchiveNavigationState()

    var sortKey: SortKeysEnum = .name
    var sortAscending: Bool = true

    /// Set to true when navigating via history (Back/Forward) to avoid re-recording
    var isNavigatingFromHistory = false

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

    /// Clear file selection on the focused panel (ESC behavior).
    /// Keeps directory and panel focus, only removes file highlight.
    func clearFileSelection() {
        let panel = focusedPanel
        log.debug("[AppState] clearFileSelection on \(panel)")

        // Clear the selected file only, marks cleared separately via unmarkAll
        switch panel {
        case .left:
            selectedLeftFile = nil
        case .right:
            selectedRightFile = nil
        }
    }

    func toggleFocus() {
        selectionManager?.toggleFocus()
    }

    func selectionMove(by step: Int) {
        selectionManager?.moveSelection(by: step)
    }
}

// MARK: - Multi-Selection Operations (Total Commander + Finder style)
extension AppState {

    /// Handle click with modifier keys (Cmd, Shift, or plain) — Finder-style multi-selection
    func handleClickWithModifiers(on file: CustomFile, modifiers: ClickModifiers) {
        multiSelectionManager?.handleClick(on: file, modifiers: modifiers)
    }

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

    func archiveState(for panel: PanelSide) -> ArchiveNavigationState {
        switch panel {
        case .left: return leftArchiveState
        case .right: return rightArchiveState
        }
    }

    func setArchiveState(_ state: ArchiveNavigationState, for panel: PanelSide) {
        switch panel {
        case .left: leftArchiveState = state
        case .right: rightArchiveState = state
        }
    }
}

// MARK: - Archive Navigation
extension AppState {

    /// Navigate into an archive: extract to temp dir and open as directory
    func enterArchive(at archiveURL: URL, on panel: PanelSide) async {
        log.info("[AppState] Entering archive: \(archiveURL.lastPathComponent) panel=\(panel)")
        do {
            let tempDir = try await ArchiveManager.shared.openArchive(at: archiveURL)

            var state = archiveState(for: panel)
            state.enterArchive(archiveURL: archiveURL, tempDir: tempDir)
            setArchiveState(state, for: panel)

            updatePath(tempDir.path, for: panel)
            if panel == .left {
                await scanner.setLeftDirectory(pathStr: tempDir.path)
                await scanner.refreshFiles(currSide: .left)
                await refreshLeftFiles()
            } else {
                await scanner.setRightDirectory(pathStr: tempDir.path)
                await scanner.refreshFiles(currSide: .right)
                await refreshRightFiles()
            }

            log.info("[AppState] Successfully entered archive: \(archiveURL.lastPathComponent)")
        } catch {
            log.error("[AppState] Failed to enter archive: \(error.localizedDescription)")
        }
    }

    /// Navigate out of an archive: close session (repack if dirty), go to archive's parent dir
    func exitArchive(on panel: PanelSide) async {
        let state = archiveState(for: panel)
        guard state.isInsideArchive, let archiveURL = state.archiveURL else {
            log.warning("[AppState] exitArchive called but not inside archive on panel=\(panel)")
            return
        }

        let parentDir = archiveURL.deletingLastPathComponent().path
        log.info("[AppState] Exiting archive: \(archiveURL.lastPathComponent) → \(parentDir)")

        do {
            try await ArchiveManager.shared.closeArchive(at: archiveURL, repackIfDirty: true)
        } catch {
            log.error("[AppState] Error closing archive: \(error.localizedDescription)")
        }

        var newState = archiveState(for: panel)
        newState.exitArchive()
        setArchiveState(newState, for: panel)

        updatePath(parentDir, for: panel)
        if panel == .left {
            await scanner.setLeftDirectory(pathStr: parentDir)
            await scanner.refreshFiles(currSide: .left)
            await refreshLeftFiles()
        } else {
            await scanner.setRightDirectory(pathStr: parentDir)
            await scanner.refreshFiles(currSide: .right)
            await refreshRightFiles()
        }
    }

    /// Handle ".." (parent directory) navigation — archive-aware
    func navigateToParent(on panel: PanelSide) async {
        let state = archiveState(for: panel)
        let currentPath = panel == .left ? leftPath : rightPath

        // If at the root of an extracted archive → exit archive entirely
        if state.isInsideArchive && state.isAtArchiveRoot(currentPath: currentPath) {
            await exitArchive(on: panel)
            return
        }

        // Normal parent navigation
        let parentURL = URL(fileURLWithPath: currentPath).deletingLastPathComponent()
        let parentPath = parentURL.path

        updatePath(parentPath, for: panel)
        if panel == .left {
            await scanner.setLeftDirectory(pathStr: parentPath)
            await scanner.refreshFiles(currSide: .left)
            await refreshLeftFiles()
        } else {
            await scanner.setRightDirectory(pathStr: parentPath)
            await scanner.refreshFiles(currSide: .right)
            await refreshRightFiles()
        }
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

        // Record directory change in navigation history (enables Back/Forward)
        // Skip if navigating via history goBack/goForward to avoid corrupting the index
        if !isNavigatingFromHistory {
            selectionsHistory.add(path)
        }

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
        Task {
            await ArchiveManager.shared.cleanup()
        }
    }
}
