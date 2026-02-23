// AppState.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 28.05.2025.
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

    // MARK: - Panel file filter queries (persisted via AppStorage in SelectionStatusBar)
    var leftFilterQuery: String = ""
    var rightFilterQuery: String = ""
    var leftPath: String
    var rightPath: String
    var selectedDir: DirectorySelection = .init()
    var showFavTreePopup: Bool = false
    var showNetworkNeighborhood: Bool = false

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

    // MARK: - Tab Managers (per-panel)
    private(set) var leftTabManager: TabManager!
    private(set) var rightTabManager: TabManager!

    // MARK: - Sub-managers (lazy initialized)
    private(set) var selectionManager: SelectionManager?
    private(set) var multiSelectionManager: MultiSelectionManager?
    private(set) var fileActions: FileOperationActions?
    let selectionsHistory = SelectionsHistory()
    var scanner: DualDirectoryScanner!

    // MARK: - Per-Panel Navigation History (for Back/Forward buttons)
    private(set) var leftNavigationHistory: PanelNavigationHistory!
    private(set) var rightNavigationHistory: PanelNavigationHistory!

    // MARK: - Initialization
    init() {
        log.info("[AppState] init")

        let paths = StatePersistence.loadInitialPaths()
        self.leftPath = paths.left
        self.rightPath = paths.right
        self.focusedPanel = StatePersistence.loadInitialFocus()

        // Initialize tab managers
        self.leftTabManager = TabManager(panelSide: .left, initialPath: paths.left)
        self.rightTabManager = TabManager(panelSide: .right, initialPath: paths.right)

        // Initialize per-panel navigation history
        self.leftNavigationHistory = PanelNavigationHistory(panel: .left)
        self.rightNavigationHistory = PanelNavigationHistory(panel: .right)

        // Seed navigation history with initial paths (if history is empty)
        if leftNavigationHistory.currentPath == nil {
            leftNavigationHistory.navigateTo(paths.left)
        }
        if rightNavigationHistory.currentPath == nil {
            rightNavigationHistory.navigateTo(paths.right)
        }

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

    /// Select a file by name on the given panel.
    /// Searches displayedFiles and sets it as selected if found.
    func selectFileByName(_ name: String, on panel: PanelSide) {
        let files = displayedFiles(for: panel)
        if let match = files.first(where: { $0.nameStr == name }) {
            switch panel {
                case .left: selectedLeftFile = match
                case .right: selectedRightFile = match
            }
            log.debug("[AppState] selectFileByName '\(name)' on \(panel) → found")
        } else {
            log.debug("[AppState] selectFileByName '\(name)' on \(panel) → not found in \(files.count) files")
        }
    }

    /// Refresh a panel and then select a file by name.
    /// Use after creating files/folders to highlight the new item.
    func refreshAndSelect(name: String, on panel: PanelSide) async {
        if panel == .left {
            await scanner.refreshFiles(currSide: .left)
            await refreshLeftFiles()
        } else {
            await scanner.refreshFiles(currSide: .right)
            await refreshRightFiles()
        }
        selectFileByName(name, on: panel)
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
        // Direct mutation — avoids weak-ref chain through selectionManager
        focusedPanel = focusedPanel == .left ? .right : .left
        log.debug("[AppState] toggleFocus → \(focusedPanel)")
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
        let raw: [CustomFile]
        let query: String
        switch panelSide {
            case .left:
                raw = displayedLeftFiles
                query = leftFilterQuery
            case .right:
                raw = displayedRightFiles
                query = rightFilterQuery
        }
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return raw }
        let lower = trimmed.lowercased()
        return raw.filter { file in
            file.nameStr.lowercased().contains(lower)
        }
    }

    func pathURL(for panelSide: PanelSide) -> URL? {
        let path = panelSide == .left ? leftPath : rightPath
        return URL(fileURLWithPath: path)
    }

    /// TabManager for given panel side
    func tabManager(for panel: PanelSide) -> TabManager {
        switch panel {
            case .left: return leftTabManager
            case .right: return rightTabManager
        }
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

            // Sync tab with archive state
            tabManager(for: panel).updateActiveTabForArchive(extractedPath: tempDir.path, archiveURL: archiveURL)

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

    /// Navigate out of an archive: optionally repack if dirty (asks user), go to archive's parent dir
    func exitArchive(on panel: PanelSide) async {
        let state = archiveState(for: panel)
        guard state.isInsideArchive, let archiveURL = state.archiveURL else {
            log.warning("[AppState] exitArchive called but not inside archive on panel=\(panel)")
            return
        }

        let parentDir = archiveURL.deletingLastPathComponent().path
        log.info("[AppState] Exiting archive: \(archiveURL.lastPathComponent) → \(parentDir)")

        // Check if archive was modified (dirty check via manager)
        let session = await ArchiveManager.shared.sessionForArchive(at: archiveURL)
        let sessionDirty = session?.isDirty ?? false
        let fsDirty = await ArchiveManager.shared.isDirty(archiveURL: archiveURL)
        let isDirty = sessionDirty || fsDirty

        var shouldRepack = false
        if isDirty {
            shouldRepack = await confirmRepack(archiveName: archiveURL.lastPathComponent)
        }

        do {
            try await ArchiveManager.shared.closeArchive(at: archiveURL, repackIfDirty: shouldRepack)
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

    /// Shows NSAlert asking user whether to repack the modified archive.
    /// Returns true if user chose to repack.
    @MainActor
    private func confirmRepack(archiveName: String) async -> Bool {
        return await withCheckedContinuation { continuation in
            let alert = NSAlert()
            alert.messageText = "Archive Modified"
            alert.informativeText = "\"\(archiveName)\" has been modified.\n\nRepack the archive with your changes?"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Repack")  // NSAlertFirstButtonReturn
            alert.addButton(withTitle: "Discard Changes")  // NSAlertSecondButtonReturn
            let response = alert.runModal()
            continuation.resume(returning: response == .alertFirstButtonReturn)
        }
    }

    /// Handle ".." (parent directory) navigation — archive-aware
    func navigateToParent(on panel: PanelSide) async {
        let state = archiveState(for: panel)
        let currentPath = panel == .left ? leftPath : rightPath

        // Remote path — navigate up via RemoteConnectionManager
        if Self.isRemotePath(currentPath) {
            let manager = RemoteConnectionManager.shared
            guard let conn = manager.activeConnection else { return }
            let parentRemote = (conn.currentPath as NSString).deletingLastPathComponent
            let normalizedParent = parentRemote.isEmpty ? "/" : parentRemote
            log.info("[AppState] navigateToParent remote: \(conn.currentPath) \u2192 \(normalizedParent)")
            do {
                let items = try await manager.listDirectory(normalizedParent)
                let files = items.map { CustomFile(remoteItem: $0) }
                let sorted = applySorting(files)
                let mountPath = conn.provider.mountPath
                let displayPath = mountPath.hasSuffix("/") ? String(mountPath.dropLast()) : mountPath
                updatePath(displayPath + normalizedParent, for: panel)
                switch panel {
                case .left:
                    displayedLeftFiles = sorted
                    selectedLeftFile = sorted.first
                case .right:
                    displayedRightFiles = sorted
                    selectedRightFile = sorted.first
                }
            } catch {
                log.error("[AppState] remote navigateToParent failed: \(error.localizedDescription)")
            }
            return
        }

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

        // Sync active tab path
        tabManager(for: panelSide).updateActiveTabPath(path)

        // Record directory change in navigation history (enables Back/Forward)
        // Skip if navigating via history goBack/goForward to avoid corrupting the index
        if !isNavigatingFromHistory {
            // Record in per-panel navigation history (for Back/Forward buttons)
            navigationHistory(for: panelSide).navigateTo(path)
            // Also record in global selections history (for recent directories)
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

// MARK: - Remote Path Detection
extension AppState {
    /// Returns true if the path belongs to an active remote connection
    nonisolated static func isRemotePath(_ path: String) -> Bool {
        path.hasPrefix("sftp://") || path.hasPrefix("ftp://") || path.hasPrefix("/sftp:") || path.hasPrefix("/ftp:")
    }

    /// Fetch remote directory listing and populate panel files
    func refreshRemoteFiles(for panel: PanelSide) async {
        let manager = RemoteConnectionManager.shared
        guard let conn = manager.activeConnection else {
            log.error("[AppState] refreshRemoteFiles — no active connection")
            return
        }
        do {
            let remotePath = conn.currentPath
            log.info("[AppState] refreshRemoteFiles panel=\(panel) path=\(remotePath)")
            let items = try await manager.listDirectory(remotePath)
            let files = items.map { CustomFile(remoteItem: $0) }
            let sorted = applySorting(files)
            switch panel {
            case .left:
                displayedLeftFiles = sorted
                if selectedLeftFile == nil { selectedLeftFile = sorted.first }
            case .right:
                displayedRightFiles = sorted
                if selectedRightFile == nil { selectedRightFile = sorted.first }
            }
            log.debug("[AppState] remote listing: \(sorted.count) items")
        } catch {
            log.error("[AppState] remote listing failed: \(error.localizedDescription)")
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
        if Self.isRemotePath(leftPath) {
            await refreshRemoteFiles(for: .left)
        } else {
            await scanner.refreshFiles(currSide: .left)
        }
        if focusedPanel == .left, selectedLeftFile == nil {
            selectedLeftFile = displayedLeftFiles.first
            if let f = selectedLeftFile {
                log.debug("[AppState] auto-selected L: \(f.nameStr)")
            }
        }
    }

    func refreshRightFiles() async {
        log.debug("[AppState] refreshRightFiles path=\(rightPath)")
        if Self.isRemotePath(rightPath) {
            await refreshRemoteFiles(for: .right)
        } else {
            await scanner.refreshFiles(currSide: .right)
        }
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

    // MARK: - Swap panels — exchange left ↔ right paths, tabs and selection
    func swapPanels() {
        log.info("[AppState] swapPanels: L=\(leftPath) ↔ R=\(rightPath)")

        let tmpPath = leftPath
        leftPath = rightPath
        rightPath = tmpPath

        tabManager(for: .left).updateActiveTabPath(leftPath)
        tabManager(for: .right).updateActiveTabPath(rightPath)

        let tmpSel = selectedLeftFile
        selectedLeftFile = selectedRightFile
        selectedRightFile = tmpSel

        Task {
            await scanner.setLeftDirectory(pathStr: leftPath)
            await scanner.setRightDirectory(pathStr: rightPath)
            await refreshLeftFiles()
            await refreshRightFiles()
            log.debug("[AppState] swapPanels done: L=\(leftPath) R=\(rightPath)")
        }
    }
}

// MARK: - Lifecycle
extension AppState {

    func initialize() {
        log.debug("[AppState] initialize")
        UserPreferences.shared.load()
        UserPreferences.shared.apply(to: self)
        StatePersistence.restoreTabs(into: self)

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

    // MARK: - Navigation History Helpers

    /// Get navigation history for specified panel
    func navigationHistory(for panel: PanelSide) -> PanelNavigationHistory {
        panel == .left ? leftNavigationHistory : rightNavigationHistory
    }

    /// Record navigation to path (called when entering directories)
    func recordNavigation(to path: String, panel: PanelSide) {
        guard !isNavigatingFromHistory else {
            log.debug("[AppState] recordNavigation skipped (navigating from history)")
            return
        }
        navigationHistory(for: panel).navigateTo(path)
    }
}
