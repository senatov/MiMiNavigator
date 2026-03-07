// AppState.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 28.05.2025.
// Copyright © 2025-2026 Senatov. All rights reserved.
// Description: Central application state - coordinates sub-managers

import AppKit
import FileModelKit
import Foundation

// MARK: - App State
/// Central observable state for the dual-panel file manager
@MainActor
@Observable
final class AppState {

    // MARK: - Observable State
    // Version counters: SwiftUI onChange(of:) compares these Int values — O(1) instead of O(n) array diff.
    // Incremented atomically with every file list replacement.
    private(set) var leftFilesVersion: Int = 0
    private(set) var rightFilesVersion: Int = 0
    var displayedLeftFiles: [CustomFile] = [] {
        didSet { leftFilesVersion &+= 1 }
    }
    var displayedRightFiles: [CustomFile] = [] {
        didSet { rightFilesVersion &+= 1 }
    }
    var focusedPanel: PanelSide = .left

    // MARK: - Panel file filter queries (persisted via AppStorage in SelectionStatusBar)
    var leftFilterQuery: String = ""
    var rightFilterQuery: String = ""
    var leftPath: String
    var rightPath: String
    /// Saved local paths before switching to remote (for disconnect/restore)
    var savedLocalLeftPath: String?
    var savedLocalRightPath: String?
    var selectedDir: DirectorySelection = .init()
    var showFavTreePopup: Bool = false
    var showNetworkNeighborhood: Bool = false

    // MARK: - Archive Navigation State (per-panel)
    var leftArchiveState = ArchiveNavigationState()
    var rightArchiveState = ArchiveNavigationState()

    // MARK: - Search Results State (per-panel)
    /// Non-nil when a panel is showing virtual search results instead of a real directory.
    /// The path bar shows this virtual path and a Clear button.
    var leftSearchResultsPath: String?
    var rightSearchResultsPath: String?
    /// Archive paths opened for search results (per panel).
    /// Used by clearSearchResults to check dirty state and offer repack.
    var searchResultArchives: [PanelSide: Set<String>] = [:]

    var sortKey: SortKeysEnum = .name
    var bSortAscending: Bool = true

    /// Set to true when navigating via history (Back/Forward) to avoid re-recording
    var isNavigatingFromHistory = false

    // MARK: - First real file helper (skips virtual ".." parent entry)
    private func firstRealFile(_ files: [CustomFile]) -> CustomFile? {
        files.first { !$0.isParentEntry }
    }

    var selectedLeftFile: CustomFile? {
        didSet { selectionManager?.recordSelection(.left, file: selectedLeftFile) }
    }
    var selectedRightFile: CustomFile? {
        didSet { selectionManager?.recordSelection(.right, file: selectedRightFile) }
    }

    // MARK: - Multi-Selection State (Total Commander style marking)
    var markedLeftFiles: Set<String> = []
    var markedRightFiles: Set<String> = []

    // MARK: - Per-Panel Selected Index (for status bar display, updated by FileTableView)
    /// 1-based index of selected file in left panel (0 = none)
    var leftSelectedIndex: Int = 0
    /// 1-based index of selected file in right panel (0 = none)
    var rightSelectedIndex: Int = 0

    /// Get selected index for panel
    func selectedIndex(for panel: PanelSide) -> Int {
        panel == .left ? leftSelectedIndex : rightSelectedIndex
    }

    /// Set selected index for panel (called from FileTableView when selection changes)
    func setSelectedIndex(_ index: Int, for panel: PanelSide) {
        if panel == .left { leftSelectedIndex = index } else { rightSelectedIndex = index }
    }

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
            await refreshLeftFiles()
        } else {
            await refreshRightFiles()
        }
        selectFileByName(name, on: panel)
    }

    /// Refresh a panel after file removal (delete/move) and select the next file.
    /// Finds the position of the last removed file in the old list, then after refresh
    /// selects the file that now occupies that position (or the last file if beyond bounds).
    func refreshAndSelectAfterRemoval(removedFiles: [CustomFile], on panel: PanelSide) async {
        let oldFiles = displayedFiles(for: panel)
        let removedNames = Set(removedFiles.map { $0.nameStr })
        var lastRemovedIndex = 0
        for (index, file) in oldFiles.enumerated() where removedNames.contains(file.nameStr) {
            lastRemovedIndex = index
        }
        log.debug("[AppState] refreshAndSelectAfterRemoval: lastRemovedIndex=\(lastRemovedIndex) oldFiles=\(oldFiles.count) panel=\(panel)")
        if panel == .left {
            await refreshLeftFiles()
        } else {
            await refreshRightFiles()
        }
        let newFiles = displayedFiles(for: panel)
        guard !newFiles.isEmpty else {
            log.debug("[AppState] refreshAndSelectAfterRemoval: newFiles is empty")
            return
        }
        var targetIndex = min(lastRemovedIndex, newFiles.count - 1)
        // Skip virtual ".." parent entry
        if newFiles[targetIndex].isParentEntry && targetIndex + 1 < newFiles.count {
            targetIndex += 1
        }
        let targetFile = newFiles[targetIndex]
        // Set selection directly without changing focusedPanel
        switch panel {
            case .left:  selectedLeftFile = targetFile
            case .right: selectedRightFile = targetFile
        }
        log.info("[AppState] refreshAndSelectAfterRemoval on \(panel) → index \(targetIndex) '\(targetFile.nameStr)' (of \(newFiles.count))")
    }

    func clearSelection(on panelSide: PanelSide) {
        selectionManager?.clearSelection(on: panelSide)
    }

    /// Clear file selection on the focused panel (ESC behavior).
    /// Keeps directory and panel focus, only removes file highlight.
    func clearFileSelection() {
        let panel = focusedPanel

        // Clear the selected file only, marks cleared separately via unmarkAll
        switch panel {
            case .left:
                selectedLeftFile = nil
            case .right:
                selectedRightFile = nil
        }
    }

    func toggleFocus() {
        focusedPanel = focusedPanel == .left ? .right : .left
        ensureSelectionOnFocusedPanel()
    }

    /// If the newly focused panel has no selected file, select the topmost one.
    func ensureSelectionOnFocusedPanel() {
        switch focusedPanel {
            case .left:
                guard selectedLeftFile == nil else { return }
                if let first = displayedLeftFiles.first(where: { !$0.isParentEntry }) {
                    selectedLeftFile = first
                }
            case .right:
                guard selectedRightFile == nil else { return }
                if let first = displayedRightFiles.first(where: { !$0.isParentEntry }) {
                    selectedRightFile = first
                }
        }
    }

    func selectionMove(by step: Int) {
        selectionManager?.moveSelection(by: step)
    }

    func selectionMoveToEdge(top: Bool) {
        selectionManager?.moveToEdge(top: top)
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

    /// Clear marks on specific panel
    func unmarkAll(on panel: PanelSide) {
        setMarkedFiles([], for: panel)
        log.debug("[AppState] cleared all marks on \(panel)")
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

    // MARK: - Activate item (Enter key or double-click) — Finder-consistent behaviour
    /// Directories: navigate into. Archives: open as virtual dir. Apps: launch. Files: open with default app.
    func activateItem(_ file: CustomFile, on panel: PanelSide) {
        // ".." parent shortcut
        if ParentDirectoryEntry.isParentEntry(file) {
            Task { await navigateToParent(on: panel) }
            return
        }
        // Archives — open as virtual directory
        if !file.isDirectory && ArchiveExtensions.isArchive(file.fileExtension) {
            Task { await enterArchive(at: file.urlValue, on: panel) }
            return
        }
        // .app bundles — launch, never browse inside
        let ext = file.fileExtension.lowercased()
        if ext == "app" {
            NSWorkspace.shared.openApplication(
                at: file.urlValue,
                configuration: NSWorkspace.OpenConfiguration()
            ) { _, error in
                if let error { log.error("[AppState] launch app failed: \(error.localizedDescription)") }
            }
            return
        }
        // Directories and symlink-dirs — navigate into
        if file.isDirectory || file.isSymbolicDirectory {
            let resolvedURL = file.urlValue.resolvingSymlinksInPath()
            let newPath = resolvedURL.path
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: newPath, isDirectory: &isDir),
                isDir.boolValue
            else {
                log.warning("[AppState] activateItem: broken symlink or gone: \(newPath)")
                return
            }
            Task { @MainActor in
                updatePath(newPath, for: panel)
                // Reset selection so refreshFiles auto-selects first real file in new dir
                if panel == .left { selectedLeftFile = nil } else { selectedRightFile = nil }
                multiSelectionManager?.resetAnchor(for: panel)
                if panel == .left {
                    await scanner.setLeftDirectory(pathStr: newPath)
                    await refreshLeftFiles()
                } else {
                    await scanner.setRightDirectory(pathStr: newPath)
                    await refreshRightFiles()
                }
            }
            return
        }
        // Regular file — open with default app
        NSWorkspace.shared.open(
            [file.urlValue],
            withApplicationAt: NSWorkspace.shared.urlForApplication(toOpen: file.urlValue)
                ?? URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app"),
            configuration: NSWorkspace.OpenConfiguration()
        ) { _, error in
            if let error { log.error("[AppState] open file failed: \(error.localizedDescription)") }
        }
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

    /// Bridge for nonisolated callers (e.g. DualDirectoryScanner actor) that need
    /// the current showHiddenFiles value from @MainActor-isolated UserPreferences.
    func showHiddenFilesSnapshot() -> Bool {
        UserPreferences.shared.snapshot.showHiddenFiles
    }
}

// MARK: - Archive Navigation
extension AppState {

    /// Navigate into an archive: extract to temp dir and open as directory
    func enterArchive(at archiveURL: URL, on panel: PanelSide, password: String? = nil) async {
        log.info("[AppState] Entering archive: \(archiveURL.lastPathComponent) panel=\(panel) hasPassword=\(password != nil)")
        ArchiveProgressPanel.shared.show(
            archiveName: archiveURL.lastPathComponent,
            destinationPath: archiveURL.deletingLastPathComponent().path
        )
        do {
            let tempDir = try await ArchiveManager.shared.openArchive(at: archiveURL, password: password)
            ArchiveProgressPanel.shared.hide()

            var state = archiveState(for: panel)
            state.enterArchive(archiveURL: archiveURL, tempDir: tempDir)
            setArchiveState(state, for: panel)

            // Sync tab with archive state
            tabManager(for: panel).updateActiveTabForArchive(extractedPath: tempDir.path, archiveURL: archiveURL)

            updatePath(tempDir.path, for: panel)
            if panel == .left {
                await scanner.setLeftDirectory(pathStr: tempDir.path)
                await refreshLeftFiles()
            } else {
                await scanner.setRightDirectory(pathStr: tempDir.path)
                await refreshRightFiles()
            }

            log.info("[AppState] Successfully entered archive: \(archiveURL.lastPathComponent)")
        } catch {
            ArchiveProgressPanel.shared.hide()
            log.error("[AppState] Failed to enter archive: \(error.localizedDescription)")
            await showArchiveErrorAlert(archiveName: archiveURL.lastPathComponent, archiveURL: archiveURL, error: error, panel: panel)
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
            await refreshLeftFiles()
        } else {
            await scanner.setRightDirectory(pathStr: parentDir)
            await refreshRightFiles()
        }
    }

    /// Shows NSAlert when archive open fails (encrypted, corrupted, etc.)
    @MainActor
    private func showArchiveErrorAlert(archiveName: String, archiveURL: URL, error: Error, panel: PanelSide) async {
        let desc = error.localizedDescription
        let isEncrypted = desc.lowercased().contains("password") || desc.lowercased().contains("encrypted")
        
        let alert = NSAlert()
        alert.alertStyle = isEncrypted ? .warning : .critical
        
        if isEncrypted {
            alert.messageText = "Password Required"
            alert.informativeText = "\"\(archiveName)\" is password-protected.\nEnter password to open:"
            
            let passwordField = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
            passwordField.placeholderString = "Enter password"
            alert.accessoryView = passwordField
            
            alert.addButton(withTitle: "Open")
            alert.addButton(withTitle: "Open with App")
            alert.addButton(withTitle: "Cancel")
            
            alert.window.initialFirstResponder = passwordField
            let response = alert.runModal()
            
            if response == .alertFirstButtonReturn {
                let password = passwordField.stringValue
                log.debug("[Password dialog] entered password len=\(password.count)")
                if !password.isEmpty {
                    await enterArchive(at: archiveURL, on: panel, password: password)
                }
            } else if response == .alertSecondButtonReturn {
                NSWorkspace.shared.open(archiveURL)
            }
        } else {
            alert.messageText = "Cannot Open Archive"
            alert.informativeText = "\"\(archiveName)\" could not be opened.\n\n\(desc)"
            alert.addButton(withTitle: "OK")
            alert.runModal()
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
            log.info("[AppState] navigateToParent remote: \(conn.currentPath) -> \(normalizedParent)")
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
                        selectedLeftFile = firstRealFile(sorted)
                    case .right:
                        displayedRightFiles = sorted
                        selectedRightFile = firstRealFile(sorted)
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
            await refreshLeftFiles()
        } else {
            await scanner.setRightDirectory(pathStr: parentPath)
            await refreshRightFiles()
        }
    }
}

// MARK: - Sorting
extension AppState {

    // MARK: -
    func updateSorting(key: SortKeysEnum? = nil, ascending: Bool? = nil) {
        if let key { sortKey = key }
        if let ascending { bSortAscending = ascending }

        // Sort BOTH panels to keep them in sync
        let leftSorted = FileSortingService.sort(
            displayedLeftFiles,
            by: sortKey,
            bDirection: bSortAscending
        )
        let rightSorted = FileSortingService.sort(
            displayedRightFiles,
            by: sortKey,
            bDirection: bSortAscending
        )
        displayedLeftFiles = leftSorted
        displayedRightFiles = rightSorted
    }

    // MARK: -
    func applySorting(_ items: [CustomFile]) -> [CustomFile] {
        FileSortingService.sort(items, by: sortKey, bDirection: bSortAscending)
    }
}

// MARK: - Path Updates
extension AppState {

    func updatePath(_ path: String, for panelSide: PanelSide) {
        let currentPath = panelSide == .left ? leftPath : rightPath

        guard !PathUtils.areEqual(currentPath, path) else {
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
                // Save local path before switching to remote
                if Self.isRemotePath(path) && !Self.isRemotePath(leftPath) {
                    savedLocalLeftPath = leftPath
                }
                leftPath = path
                selectedLeftFile = firstRealFile(displayedLeftFiles)
            case .right:
                if Self.isRemotePath(path) && !Self.isRemotePath(rightPath) {
                    savedLocalRightPath = rightPath
                }
                rightPath = path
                selectedRightFile = firstRealFile(displayedRightFiles)
        }
    }

    /// Restore panel to saved local path after remote disconnect
    func restoreLocalPath(for panel: PanelSide) async {
        let saved: String?
        switch panel {
            case .left: saved = savedLocalLeftPath
            case .right: saved = savedLocalRightPath
        }
        guard let localPath = saved else {
            log.warning("[AppState] no saved local path for \(panel)")
            return
        }
        log.info("[AppState] restoring local path \(panel): \(localPath)")
        updatePath(localPath, for: panel)
        if panel == .left {
            await scanner.setLeftDirectory(pathStr: localPath)
            await refreshLeftFiles()
        } else {
            await scanner.setRightDirectory(pathStr: localPath)
            await refreshRightFiles()
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
                    if selectedLeftFile == nil { selectedLeftFile = firstRealFile(sorted) }
                case .right:
                    displayedRightFiles = sorted
                    if selectedRightFile == nil { selectedRightFile = firstRealFile(sorted) }
            }
        } catch {
            log.error("[AppState] remote listing failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - Refresh Operations
extension AppState {

    @Sendable
    func refreshFiles() async {
        await refreshLeftFiles()
        await refreshRightFiles()
    }

    func refreshLeftFiles() async {
        if Self.isRemotePath(leftPath) {
            await refreshRemoteFiles(for: .left)
        } else {
            await scanner.refreshFiles(currSide: .left)
        }
        if selectedLeftFile == nil {
            selectedLeftFile = firstRealFile(displayedLeftFiles)
            if let f = selectedLeftFile {
                log.debug("[AppState] 👆 \(f.nameStr) selected (left)")
            }
        }
    }

    func refreshRightFiles() async {
        if Self.isRemotePath(rightPath) {
            await refreshRemoteFiles(for: .right)
        } else {
            await scanner.refreshFiles(currSide: .right)
        }
        if selectedRightFile == nil {
            selectedRightFile = firstRealFile(displayedRightFiles)
            if let f = selectedRightFile {
                log.debug("[AppState] 👆 \(f.nameStr) selected (right)")
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

    // MARK: - SpinnerWatchdog setup
    private func setupSpinnerWatchdog() {
        let watchdog = SpinnerWatchdog.shared
        watchdog.addSource(name: "BatchOperation") {
            BatchOperationManager.shared.showProgressDialog
        }
        watchdog.start()
        log.info("[AppState] SpinnerWatchdog started")
    }

    func initialize() {
        log.debug("[AppState] initialize")
        setupSpinnerWatchdog()
        UserPreferences.shared.load()
        UserPreferences.shared.apply(to: self)
        StatePersistence.restoreTabs(into: self)
        StatePersistence.restoreSorting(into: self)

        // Step 1: show startup cache synchronously — UI is responsive before Task runs
        // Focus always starts on left panel, first file selected
        focusedPanel = .left
        if let cached = PanelStartupCache.shared.load(forLeftPath: leftPath, rightPath: rightPath) {
            displayedLeftFiles = cached.left
            displayedRightFiles = cached.right
            selectedLeftFile = firstRealFile(cached.left)
            selectedRightFile = firstRealFile(cached.right)
            log.info("[AppState] startup cache applied — L=\(cached.left.count) R=\(cached.right.count)")
        }

        // Step 2: background scan — does NOT block MainActor
        // Both panels scan in parallel via async let; monitoring starts immediately
        // so FSEvents is active even before first scan completes.
        Task {
            await scanner.setLeftDirectory(pathStr: leftPath)
            await scanner.setRightDirectory(pathStr: rightPath)
            await scanner.startMonitoring()

            // Parallel scan — neither panel waits for the other
            async let leftScan: Void = refreshLeftFiles()
            async let rightScan: Void = refreshRightFiles()
            _ = await (leftScan, rightScan)

            selectionManager?.restoreSelectionsAndFocus()

            // Always ensure left panel has a selection and focus after startup
            focusedPanel = .left
            if selectedLeftFile == nil {
                selectedLeftFile = firstRealFile(displayedLeftFiles)
                log.debug("[AppState] startup: auto-selected first file L: \(selectedLeftFile?.nameStr ?? "none")")
            }

            // Save fresh data for next startup
            PanelStartupCache.shared.save(
                leftPath: leftPath,
                rightPath: rightPath,
                leftFiles: displayedLeftFiles,
                rightFiles: displayedRightFiles
            )
            log.info("[AppState] initialization complete")
        }
    }

    func saveBeforeExit() {
        StatePersistence.saveBeforeExit(from: self)
        // Cache current panel contents for instant display on next startup
        PanelStartupCache.shared.save(
            leftPath: leftPath,
            rightPath: rightPath,
            leftFiles: displayedLeftFiles,
            rightFiles: displayedRightFiles
        )
        // ArchiveManager is an actor — schedule cleanup fire-and-forget;
        // AppDelegate.performCleanupBeforeExit() awaits it properly via stopMonitoring chain
        Task { await ArchiveManager.shared.cleanup() }
    }

    // MARK: - Navigation History Helpers

    /// Get navigation history for specified panel
    func navigationHistory(for panel: PanelSide) -> PanelNavigationHistory {
        panel == .left ? leftNavigationHistory : rightNavigationHistory
    }

    /// Record navigation to path (called when entering directories)
    func recordNavigation(to path: String, panel: PanelSide) {
        guard !isNavigatingFromHistory else {
            return
        }
        navigationHistory(for: panel).navigateTo(path)
    }
}

// MARK: - Search Results in Panel
extension AppState {

    /// Whether the given panel is showing virtual search results
    func isShowingSearchResults(on panel: PanelSide) -> Bool {
        switch panel {
            case .left: return leftSearchResultsPath != nil
            case .right: return rightSearchResultsPath != nil
        }
    }

    /// Inject search results into the focused panel as a virtual file list.
    /// The panel shows the results with a virtual path; normal navigation clears the state.
    func showSearchResults(_ files: [CustomFile], virtualPath: String, on panel: PanelSide) {
        let sorted = applySorting(files)
        log.info("[AppState] showSearchResults: \(sorted.count) files on \(panel) path='\(virtualPath)'")
        switch panel {
            case .left:
                leftSearchResultsPath = virtualPath
                displayedLeftFiles = sorted
                leftPath = virtualPath
                selectedLeftFile = firstRealFile(sorted)
            case .right:
                rightSearchResultsPath = virtualPath
                displayedRightFiles = sorted
                rightPath = virtualPath
                selectedRightFile = firstRealFile(sorted)
        }
        focusedPanel = panel
    }

    /// Clear virtual search results and restore the previous real directory.
    /// For archive-backed results, checks if any archives were modified and offers repack.
    func clearSearchResults(on panel: PanelSide) {
        guard isShowingSearchResults(on: panel) else { return }
        log.info("[AppState] clearSearchResults on \(panel)")
        let archivePaths = searchResultArchives[panel] ?? []
        if !archivePaths.isEmpty {
            Task { @MainActor in
                for archivePath in archivePaths {
                    let archiveURL = URL(fileURLWithPath: archivePath)
                    let isDirty = await ArchiveManager.shared.isDirty(archiveURL: archiveURL)
                    if isDirty {
                        let shouldRepack = await confirmRepackSearchResult(
                            archiveName: archiveURL.lastPathComponent
                        )
                        do {
                            try await ArchiveManager.shared.closeArchive(
                                at: archiveURL, repackIfDirty: shouldRepack
                            )
                        } catch {
                            log.error("[AppState] repack failed: \(error.localizedDescription)")
                        }
                    } else {
                        try? await ArchiveManager.shared.closeArchive(
                            at: archiveURL, repackIfDirty: false
                        )
                    }
                }
                self.searchResultArchives[panel] = nil
                self.finishClearSearchResults(on: panel)
            }
        } else {
            searchResultArchives[panel] = nil
            finishClearSearchResults(on: panel)
        }
    }

    /// Finishes clearing search results after archive cleanup.
    private func finishClearSearchResults(on panel: PanelSide) {
        let history = navigationHistory(for: panel)
        let previousPath = history.currentPath ?? NSHomeDirectory()
        switch panel {
            case .left: leftSearchResultsPath = nil
            case .right: rightSearchResultsPath = nil
        }
        updatePath(previousPath, for: panel)
        Task {
            if panel == .left {
                await scanner.setLeftDirectory(pathStr: previousPath)
                await refreshLeftFiles()
            } else {
                await scanner.setRightDirectory(pathStr: previousPath)
                await refreshRightFiles()
            }
        }
    }

    /// Asks user whether to repack a modified archive from search results.
    @MainActor
    private func confirmRepackSearchResult(archiveName: String) async -> Bool {
        return await withCheckedContinuation { continuation in
            let alert = NSAlert()
            alert.messageText = "Archive Modified"
            alert.informativeText =
                "\"\(archiveName)\" was modified while viewing search results.\n\nRepack the archive with your changes?"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Repack")
            alert.addButton(withTitle: "Discard Changes")
            let response = alert.runModal()
            continuation.resume(returning: response == .alertFirstButtonReturn)
        }
    }
}
