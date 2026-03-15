// AppState+Selection.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 11.03.2026.
// Copyright © 2025-2026 Senatov. All rights reserved.
// Description: Selection, keyboard navigation, focus management

import AppKit
import FileModelKit
import Foundation

// MARK: - Selection Operations
extension AppState {

    func select(_ file: CustomFile, on panelSide: PanelSide) {
        log.debug(#function)
        selectionManager?.select(file, on: panelSide)
    }

    func selectFileByName(_ name: String, on panel: PanelSide) {
        let files = displayedFiles(for: panel)
        if let match = files.first(where: { $0.nameStr == name }) {
            log.info("[Selection] ✅ selectFileByName found '\(name)' on \(panel) (total \(files.count) files)")
            switch panel {
                case .left: selectedLeftFile = match
                case .right: selectedRightFile = match
            }
        } else {
            log.warning("[Selection] ⚠️ selectFileByName FAILED: '\(name)' not found on \(panel) (total \(files.count) files)")
        }
    }

    func refreshAndSelect(name: String, on panel: PanelSide) async {
        log.info("[Selection] 🔄 refreshAndSelect: name='\(name)' panel=\(panel) — clearing cooldown")
        await scanner.clearCooldown(for: panel)
        if panel == .left { await refreshLeftFiles() } else { await refreshRightFiles() }
        selectFileByName(name, on: panel)
    }

    func refreshAndSelectAfterRemoval(removedFiles: [CustomFile], on panel: PanelSide) async {
        let oldFiles = displayedFiles(for: panel)
        let removedNames = Set(removedFiles.map { $0.nameStr })
        var lastRemovedIndex = 0
        for (index, file) in oldFiles.enumerated() where removedNames.contains(file.nameStr) {
            lastRemovedIndex = index
        }
        if panel == .left { await refreshLeftFiles() } else { await refreshRightFiles() }
        let newFiles = displayedFiles(for: panel)
        guard !newFiles.isEmpty else { return }
        var targetIndex = min(lastRemovedIndex, newFiles.count - 1)
        if newFiles[targetIndex].isParentEntry && targetIndex + 1 < newFiles.count { targetIndex += 1 }
        let targetFile = newFiles[targetIndex]
        switch panel {
            case .left: selectedLeftFile = targetFile
            case .right: selectedRightFile = targetFile
        }
    }

    func clearSelection(on panelSide: PanelSide) { selectionManager?.clearSelection(on: panelSide) }

    func clearFileSelection() {
        switch focusedPanel {
            case .left: selectedLeftFile = nil
            case .right: selectedRightFile = nil
        }
    }

    func toggleFocus() {
        focusedPanel = focusedPanel == .left ? .right : .left
        ensureSelectionOnFocusedPanel()
    }

    func navigateUp() { navigationCallbacks[focusedPanel]?.moveUp() }
    func navigateDown() { navigationCallbacks[focusedPanel]?.moveDown() }

    func markCurrentAndMove(direction: Int) {
        let panel = focusedPanel
        let selectedFile: CustomFile? = panel == .left ? selectedLeftFile : selectedRightFile
        guard let file = selectedFile, file.nameStr != ".." else {
            if direction < 0 { navigateUp() } else { navigateDown() }
            return
        }
        var marked = markedFiles(for: panel)
        if marked.contains(file.id) { marked.remove(file.id) } else { marked.insert(file.id) }
        setMarkedFiles(marked, for: panel)
        if direction < 0 { navigateUp() } else { navigateDown() }
    }

    func navigatePageUp() { navigationCallbacks[focusedPanel]?.pageUp() }
    func navigatePageDown() { navigationCallbacks[focusedPanel]?.pageDown() }
    func navigateToFirst() { navigationCallbacks[focusedPanel]?.jumpToFirst() }
    func navigateToLast() { navigationCallbacks[focusedPanel]?.jumpToLast() }

    func ensureSelectionOnFocusedPanel() {
        switch focusedPanel {
            case .left:
                guard selectedLeftFile == nil else { return }
                if let first = displayedLeftFiles.first(where: { !$0.isParentEntry }) { selectedLeftFile = first }
            case .right:
                guard selectedRightFile == nil else { return }
                if let first = displayedRightFiles.first(where: { !$0.isParentEntry }) { selectedRightFile = first }
        }
    }

    func selectionMove(by step: Int) { selectionManager?.moveSelection(by: step) }
    func selectionMoveToEdge(top: Bool) { selectionManager?.moveToEdge(top: top) }
}

// MARK: - File Operations (activate, open, copy)
extension AppState {

    func selectionCopy() { fileActions?.copyToOppositePanel() }
    func openSelectedItem() { fileActions?.openSelectedItem() }

    func activateItem(_ file: CustomFile, on panel: PanelSide) {
        if ParentDirectoryEntry.isParentEntry(file) {
            Task { await navigateToParent(on: panel) }
            return
        }
        if !file.isDirectory && ArchiveExtensions.isArchive(file.fileExtension) {
            Task { await enterArchive(at: file.urlValue, on: panel) }
            return
        }
        let ext = file.fileExtension.lowercased()
        if ext == "app" {
            NSWorkspace.shared.openApplication(at: file.urlValue, configuration: NSWorkspace.OpenConfiguration()) { _, error in
                if let error { log.error("[AppState] launch app failed: \(error.localizedDescription)") }
            }
            return
        }
        if file.isDirectory || file.isSymbolicDirectory {
            let resolvedURL = file.urlValue.resolvingSymlinksInPath()
            let newPath = resolvedURL.path
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: newPath, isDirectory: &isDir), isDir.boolValue else {
                log.warning("[AppState] activateItem: broken symlink: \(newPath)")
                return
            }
            Task { @MainActor in await navigateToDirectory(newPath, on: panel) }
            return
        }
        NSWorkspace.shared.open(
            [file.urlValue],
            withApplicationAt: NSWorkspace.shared.urlForApplication(toOpen: file.urlValue)
                ?? URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app"),
            configuration: NSWorkspace.OpenConfiguration()
        ) { _, error in
            if let error { log.error("[AppState] open file failed: \(error.localizedDescription)") }
        }
    }

    func revealLogFileInFinder() { FinderIntegration.revealLogFile() }
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
        return raw.filter { $0.nameStr.lowercased().contains(lower) }
    }

    func pathURL(for panelSide: PanelSide) -> URL? {
        url(for: panelSide)
    }

    func tabManager(for panel: PanelSide) -> TabManager {
        panel == .left ? leftTabManager : rightTabManager
    }

    func archiveState(for panel: PanelSide) -> ArchiveNavigationState {
        panel == .left ? leftArchiveState : rightArchiveState
    }

    func setArchiveState(_ state: ArchiveNavigationState, for panel: PanelSide) {
        if panel == .left { leftArchiveState = state } else { rightArchiveState = state }
    }

    func showHiddenFilesSnapshot() -> Bool {
        UserPreferences.shared.snapshot.showHiddenFiles
    }
}

// MARK: - Sorting
extension AppState {

    func updateSorting(key: SortKeysEnum? = nil, ascending: Bool? = nil) {
        if let key { sortKey = key }
        if let ascending { bSortAscending = ascending }
        UserDefaults.standard.set(sortKey.rawValue, forKey: "MiMiNavigator.sortKey")
        UserDefaults.standard.set(bSortAscending, forKey: "MiMiNavigator.sortAscending")
        displayedLeftFiles = FileSortingService.sort(displayedLeftFiles, by: sortKey, bDirection: bSortAscending)
        displayedRightFiles = FileSortingService.sort(displayedRightFiles, by: sortKey, bDirection: bSortAscending)
    }

    func applySorting(_ items: [CustomFile]) -> [CustomFile] {
        FileSortingService.sort(items, by: sortKey, bDirection: bSortAscending)
    }
}

// MARK: - Settings & Swap
extension AppState {

    func toggleShowHiddenFiles() {
        UserPreferences.shared.snapshot.showHiddenFiles.toggle()
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

    func swapPanels() {
        log.debug(#function + ": leftPath: \(leftPath), rightPath: \(rightPath)")
        let tmpPath = leftPath
        leftPath = rightPath
        rightPath = tmpPath
        tabManager(for: .left).updateActiveTabPath(leftURL)
        tabManager(for: .right).updateActiveTabPath(rightURL)
        let tmpSel = selectedLeftFile
        selectedLeftFile = selectedRightFile
        selectedRightFile = tmpSel
        Task {
            await scanner.setLeftDirectory(pathStr: leftPath)
            await scanner.setRightDirectory(pathStr: rightPath)
            await refreshLeftFiles()
            await refreshRightFiles()
        }
    }
}

// MARK: - Lifecycle
extension AppState {

    private func setupSpinnerWatchdog() {
        let watchdog = SpinnerWatchdog.shared
        watchdog.addSource(name: "BatchOperation") { BatchOperationManager.shared.showProgressDialog }
        watchdog.start()
    }

    func initialize() {
        setupSpinnerWatchdog()
        UserPreferences.shared.load()
        UserPreferences.shared.apply(to: self)
        StatePersistence.restoreTabs(into: self)
        StatePersistence.restoreSorting(into: self)
        focusedPanel = .left
        if let cached = PanelStartupCache.shared.load(forLeftPath: leftPath, rightPath: rightPath) {
            displayedLeftFiles = cached.left
            displayedRightFiles = cached.right
            selectedLeftFile = firstRealFile(in: cached.left)
            selectedRightFile = firstRealFile(in: cached.right)
        }
        Task {
            await scanner.setLeftDirectory(pathStr: leftPath)
            await scanner.setRightDirectory(pathStr: rightPath)
            await scanner.startMonitoring()
            async let l: Void = refreshLeftFiles()
            async let r: Void = refreshRightFiles()
            _ = await (l, r)
            selectionManager?.restoreSelectionsAndFocus()
            focusedPanel = .left
            if selectedLeftFile == nil { selectedLeftFile = firstRealFile(in: displayedLeftFiles) }
            PanelStartupCache.shared.save(
                leftPath: leftPath, rightPath: rightPath,
                leftFiles: displayedLeftFiles, rightFiles: displayedRightFiles)
        }
    }

    func saveBeforeExit() {
        StatePersistence.saveBeforeExit(from: self)
        PanelStartupCache.shared.save(
            leftPath: leftPath, rightPath: rightPath,
            leftFiles: displayedLeftFiles, rightFiles: displayedRightFiles)
        Task { await ArchiveManager.shared.cleanup() }
    }
}

// MARK: - Search Results
extension AppState {

    func isShowingSearchResults(on panel: PanelSide) -> Bool {
        (panel == .left ? leftSearchResultsPath : rightSearchResultsPath) != nil
    }

    func showSearchResults(_ files: [CustomFile], virtualPath: String, on panel: PanelSide) {
        let sorted = applySorting(files)
        log.debug(#function + ": \(sorted.count) files")
        switch panel {
            case .left:
                leftSearchResultsPath = virtualPath
                displayedLeftFiles = sorted
                leftPath = virtualPath
                selectedLeftFile = firstRealFile(in: sorted)
            case .right:
                rightSearchResultsPath = virtualPath
                displayedRightFiles = sorted
                rightPath = virtualPath
                selectedRightFile = firstRealFile(in: sorted)
        }
        focusedPanel = panel
    }

    func clearSearchResults(on panel: PanelSide) {
        guard isShowingSearchResults(on: panel) else { return }
        let archivePaths = searchResultArchives[panel] ?? []
        if !archivePaths.isEmpty {
            Task { @MainActor in
                for archivePath in archivePaths {
                    let archiveURL = URL(fileURLWithPath: archivePath)
                    let isDirty = await ArchiveManager.shared.isDirty(archiveURL: archiveURL)
                    if isDirty {
                        let shouldRepack = await confirmRepackSearchResult(archiveName: archiveURL.lastPathComponent)
                        try? await ArchiveManager.shared.closeArchive(at: archiveURL, repackIfDirty: shouldRepack)
                    } else {
                        try? await ArchiveManager.shared.closeArchive(at: archiveURL, repackIfDirty: false)
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

    private func finishClearSearchResults(on panel: PanelSide) {
        let history = navigationHistory(for: panel)
        let previousPath = history.currentPath?.path ?? NSHomeDirectory()
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

    @MainActor
    private func confirmRepackSearchResult(archiveName: String) async -> Bool {
        await withCheckedContinuation { continuation in
            let alert = NSAlert()
            alert.messageText = "Archive Modified"
            alert.informativeText = "\"\(archiveName)\" was modified while viewing search results.\n\nRepack?"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Repack")
            alert.addButton(withTitle: "Discard Changes")
            continuation.resume(returning: alert.runModal() == .alertFirstButtonReturn)
        }
    }
}
