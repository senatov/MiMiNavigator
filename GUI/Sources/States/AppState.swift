//
//  AppState.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 28.05.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import AppKit
import Combine
import Foundation

// MARK: - AppState
@MainActor final class AppState: ObservableObject {
    @Published var displayedLeftFiles: [CustomFile] = []
    @Published var displayedRightFiles: [CustomFile] = []
    @Published var focusedPanel: PanelSide = .left { didSet { syncSelectionWithFocus() } }

    @Published var leftPath: String
    @Published var rightPath: String
    @Published var selectedDir: SelectedDir = .init()
    @Published var selectedLeftFile: CustomFile? { didSet { recordSelection(.left, file: selectedLeftFile) } }
    @Published var selectedRightFile: CustomFile? { didSet { recordSelection(.right, file: selectedRightFile) } }
    @Published var showFavTreePopup: Bool = false

    // Sorting configuration
    @Published var sortKey: SortKeysEnum = .name
    @Published var sortAscending: Bool = true
    let selectionsHistory = SelectionsHistory()
    let fileManager = FileManager.default
    var scanner: DualDirectoryScanner!
    private var cancellables = Set<AnyCancellable>()

    // MARK: -
    init() {
        log.info(#function + " - Initializing AppState")
        leftPath = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first?.path ?? ""
        rightPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first?.path ?? ""
        scanner = DualDirectoryScanner(appState: self)
        // Restore saved paths
        leftPath = UserDefaults.standard.string(forKey: "lastLeftPath") ?? leftPath
        rightPath = UserDefaults.standard.string(forKey: "lastRightPath") ?? rightPath
        // Подписка на изменения selectedDir
        $selectedDir.compactMap { $0.selectedFSEntity?.urlValue.path }
            .sink { [weak self] newPath in self?.selectionsHistory.add(newPath) }
            .store(
                in: &cancellables)
        // Restore last focused panel early (default .left)
        if let raw = UserDefaults.standard.string(forKey: "lastFocusedPanel"), raw == "right" {
            focusedPanel = .right
        } else {
            focusedPanel = .left
        }
    }

    // MARK: -
    @MainActor func forceFocusSelection() { syncSelectionWithFocus() }

    // MARK: - Private helpers to persist/restore focus and selections
    private func canonicalPath(_ url: URL) -> String { return url.standardized.resolvingSymlinksInPath().path }

    // MARK: -
    private func restoreSelectionsAndFocus() {
        log.info(#function)
        let ud = UserDefaults.standard
        // Restore focused panel (default to .left)
        if let raw = ud.string(forKey: "lastFocusedPanel"), raw == "right" {
            focusedPanel = .right
        } else {
            focusedPanel = .left
        }
        // Restore selected file on the focused side only, keep other side consistent with current rules
        if focusedPanel == .left {
            if let url = ud.url(forKey: "lastSelectedLeftFilePath") {
                if let match = displayedLeftFiles.first(where: { canonicalPath($0.urlValue) == canonicalPath(url) }) {
                    selectedLeftFile = match
                    selectedRightFile = nil
                }
            }
        } else {
            if let url = ud.url(forKey: "lastSelectedRightFilePath") {
                if let match = displayedRightFiles.first(where: { canonicalPath($0.urlValue) == canonicalPath(url) }) {
                    selectedRightFile = match
                    selectedLeftFile = nil
                }
            }
        }
        // Ensure selection exists on the focused side even if restore failed
        syncSelectionWithFocus()
    }

    // MARK: - Keep selection consistent with the focused panel
    private func syncSelectionWithFocus() {
        log.info("syncSelectionWithFocus: now \(focusedPanel)")
        let ud = UserDefaults.standard
        switch focusedPanel {
        case .left:
            if selectedRightFile != nil {
                log.info("Clearing right selection because focus moved to left")
                selectedRightFile = nil
            }
            if selectedLeftFile == nil {
                // Try to restore selection from UserDefaults
                if let url = ud.url(forKey: "lastSelectedLeftFilePath") {
                    if let match = displayedLeftFiles.first(where: { canonicalPath($0.urlValue) == canonicalPath(url) })
                    {
                        log.info("Restored left selection from saved config: \(match.nameStr)")
                        selectedLeftFile = match
                    }
                }
                // If still nil, try to restore from selectionsHistory
                if selectedLeftFile == nil {
                    if let lastPath = selectionsHistory.last,
                        let match = displayedLeftFiles.first(where: { canonicalPath($0.urlValue) == lastPath })
                    {
                        log.info("Restored left selection from history: \(match.nameStr)")
                        selectedLeftFile = match
                    }
                }
                // If still nil, fallback to first item in displayedLeftFiles
                if selectedLeftFile == nil, let first = displayedLeftFiles.first {
                    log.info("Fallback: auto-select first left item: \(first.nameStr)")
                    selectedLeftFile = first
                }
            }

        case .right:
            if selectedLeftFile != nil {
                log.info("Clearing left selection because focus moved to right")
                selectedLeftFile = nil
            }
            if selectedRightFile == nil {
                // Try to restore selection from UserDefaults
                if let url = ud.url(forKey: "lastSelectedRightFilePath") {
                    if let match = displayedRightFiles.first(where: { canonicalPath($0.urlValue) == canonicalPath(url) }
                    ) {
                        log.info("Restored right selection from saved config: \(match.nameStr)")
                        selectedRightFile = match
                    }
                }
                // If still nil, try to restore from selectionsHistory
                if selectedRightFile == nil {
                    if let lastPath = selectionsHistory.last,
                        let match = displayedRightFiles.first(where: { canonicalPath($0.urlValue) == lastPath })
                    {
                        log.info("Restored right selection from history: \(match.nameStr)")
                        selectedRightFile = match
                    }
                }
                // If still nil, fallback to first item in displayedRightFiles
                if selectedRightFile == nil, let first = displayedRightFiles.first {
                    log.info("Fallback: auto-select first right item: \(first.nameStr)")
                    selectedRightFile = first
                }
            }
        }
    }

    // MARK: - History integration
    private func recordSelection(_ side: PanelSide, file: CustomFile?) {
        // Record file path into selectionsHistory when a selection changes.
        guard let f = file else { return }
        log.debug("History: set current to \(canonicalPath(f.urlValue))")
        selectionsHistory.setCurrent(to: canonicalPath(f.urlValue))
    }

    // MARK: -
    func goBackInHistory() {
        if let p = selectionsHistory.previousPath() {
            log.debug("History: previous \(p)")
            selectPath(p)
        } else {
            log.debug("History: no previous path")
        }
    }

    // MARK: -
    func goForwardInHistory() {
        if let p = selectionsHistory.nextPath() {
            log.debug("History: next \(p)")
            selectPath(p)
        } else {
            log.debug("History: no next path")
        }
    }

    // MARK: -
    private func selectPath(_ path: String) {
        // Try to select in the focused panel first; if not present then try the other.
        let target = toCanonical(from: path)
        switch focusedPanel {
        case .left:
            if let f = displayedLeftFiles.first(where: { canonicalPath($0.urlValue) == target }) {
                selectedLeftFile = f
            } else if let f = displayedRightFiles.first(where: { canonicalPath($0.urlValue) == target }) {
                focusedPanel = .right
                selectedRightFile = f
            } else {
                log.debug("History: path \(path) not found in current listings")
            }
        case .right:
            if let f = displayedRightFiles.first(where: { canonicalPath($0.urlValue) == target }) {
                selectedRightFile = f
            } else if let f = displayedLeftFiles.first(where: { canonicalPath($0.urlValue) == target }) {
                focusedPanel = .left
                selectedLeftFile = f
            } else {
                log.debug("History: path \(path) not found in current listings")
            }
        }
    }

    // MARK: - Toggle focus between left and right panel.
    func togglePanel() {
        // With two panels, Shift-Tab behavior is identical.
        // Keep this overload so commands can pass a boolean without branching here.
        focusedPanel = (focusedPanel == .left) ? .right : .left
        log.info("TAB - Focused panel toggled to: \(focusedPanel)")
    }

    // MARK: - Commands bridging (unified via AppState)
    func selectionMove(by step: Int) {
        log.debug("AppState.selectionMove(by: \(step)) | focused: \(focusedPanel)")
        let items = (focusedPanel == .left) ? displayedLeftFiles : displayedRightFiles
        guard !items.isEmpty else { return }
        // Find current index; if none, start at 0 or end depending on step
        let current: CustomFile? = (focusedPanel == .left) ? selectedLeftFile : selectedRightFile
        let currentIdx: Int
        if let cur = current {
            let curPath = canonicalPath(cur.urlValue)
            currentIdx = items.firstIndex { canonicalPath($0.urlValue) == curPath } ?? 0
        } else {
            currentIdx = (step >= 0) ? 0 : (items.count - 1)
        }
        let nextIdx = max(0, min(items.count - 1, currentIdx + step))
        let next = items[nextIdx]
        if focusedPanel == .left {
            selectedLeftFile = next
        } else {
            selectedRightFile = next
        }
        log.debug("Selection moved to index \(nextIdx): \(next.nameStr)")
    }

    // MARK: - Copy current selection from focused panel to the opposite panel's directory
    func selectionCopy() {
        log.debug("AppState.selectionCopy() | focused: \(focusedPanel)")
        // Determine source selected file
        let srcFile: CustomFile?
        let dstSide: PanelSide
        switch focusedPanel {
        case .left:
            srcFile = selectedLeftFile
            dstSide = .right
        case .right:
            srcFile = selectedRightFile
            dstSide = .left
        }
        guard let file = srcFile else {
            log.debug("Copy skipped: no selection")
            return
        }
        guard let dstDirURL = pathURL(for: dstSide) else {
            log.error("Copy failed: destination path unavailable")
            return
        }
        let srcURL = file.urlValue
        let dstURL = dstDirURL.appendingPathComponent(srcURL.lastPathComponent)
        do {
            if FileManager.default.fileExists(atPath: dstURL.path) {
                log.debug("Copy skipped: destination already exists → \(dstURL.path)")
                return
            }
            try FileManager.default.copyItem(at: srcURL, to: dstURL)
            log.info("Copied \(srcURL.lastPathComponent) → \(dstURL.path)")
            // Refresh destination listing
            Task { @MainActor in
                if dstSide == .left { await refreshLeftFiles() } else { await refreshRightFiles() }
            }
        } catch {
            log.error("Copy failed: \(error.localizedDescription)")
        }
    }

    // MARK: - AppState extension for displayedFiles
    func displayedFiles(for side: PanelSide) -> [CustomFile] {
        log.info(#function + " at side: \(side)")
        switch side {
        case .left: return displayedLeftFiles
        case .right: return displayedRightFiles
        }
    }

    // MARK: -
    func pathURL(for side: PanelSide) -> URL? {
        log.info(#function + "|side: \(side)" + "| paths: \(leftPath),| \(rightPath)")
        let path: String
        switch side {
        case .left: path = leftPath
        case .right: path = rightPath
        }
        return URL(fileURLWithPath: path)
    }

    // MARK: -
    @Sendable func refreshFiles() async {
        log.info(#function)
        await refreshLeftFiles()
        await refreshRightFiles()
    }

    // MARK: - Sorting control
    func updateSorting(key: SortKeysEnum? = nil, ascending: Bool? = nil) {
        log.info("updateSorting(key: \(key ?? sortKey), asc: \(ascending ?? sortAscending), side: \(focusedPanel))")
        if let newKey = key { sortKey = newKey }
        if let newAsc = ascending { sortAscending = newAsc }
        // Resort currently displayed files
        if focusedPanel == .left {
            displayedLeftFiles = applySorting(displayedLeftFiles)
        } else {
            displayedRightFiles = applySorting(displayedRightFiles)
        }
        log.info("updateSorting: key=\(sortKey), asc=\(sortAscending) on \(focusedPanel) side")
    }

    // MARK: - Treat real directories and symlinks-to-directories as folder-like. Bundles treated as files by default.
    private func isFolderLike(_ f: CustomFile) -> Bool {
        if f.isDirectory { return true }
        if f.isSymbolicDirectory { return true }
        // Fallback via URL if flags are not set in the model
        let url = f.urlValue
        do {
            let rv = try url.resourceValues(forKeys: [.isSymbolicLinkKey])
            if rv.isSymbolicLink == true {
                let dst = url.resolvingSymlinksInPath()
                if let r2 = try? dst.resourceValues(forKeys: [.isDirectoryKey]), r2.isDirectory == true { return true }
            }
        } catch {
            log.error("isFolderLike: failed to get resource values for \(url.path): \(error.localizedDescription)")
        }
        return false
    }

    // MARK: - apply sorting with directories pinned to the top
    func applySorting(_ items: [CustomFile]) -> [CustomFile] {
        // Stable, deterministic sorting.
        // 1) Folder-like entries (real or symbolic) are always before files (independent of ascending/descending).
        // 2) Within the same kind, use the active key and direction.
        // 3) Tie-breaker is case-insensitive name to keep order deterministic.
        log.info(#function)
        let sorted = items.sorted { (a: CustomFile, b: CustomFile) in
            // 1) Folder-like entries (real or symbolic) first
            let aIsFolder = isFolderLike(a)
            let bIsFolder = isFolderLike(b)
            if aIsFolder != bIsFolder { return aIsFolder && !bIsFolder }
            // 2) Same kind → compare by selected key
            switch sortKey {
            case .name:
                let primary = a.nameStr.localizedCaseInsensitiveCompare(b.nameStr)
                if primary != .orderedSame {
                    return sortAscending ? (primary == .orderedAscending) : (primary == .orderedDescending)
                }
                // 3) Tie-breaker by name (ascending) for stability
                return a.nameStr.localizedCaseInsensitiveCompare(b.nameStr) == .orderedAscending

            case .date:
                let da = a.modifiedDate ?? Date.distantPast
                let db = b.modifiedDate ?? Date.distantPast
                if da != db { return sortAscending ? (da < db) : (da > db) }
                // Tie-breaker by name (ascending)
                return a.nameStr.localizedCaseInsensitiveCompare(b.nameStr) == .orderedAscending

            case .size:
                let sa: Int64 = a.sizeInBytes
                let sb: Int64 = b.sizeInBytes
                if sa != sb { return sortAscending ? (sa < sb) : (sa > sb) }
                // Tie-breaker by name (ascending)
                return a.nameStr.localizedCaseInsensitiveCompare(b.nameStr) == .orderedAscending
            }
        }
        log.info("applySorting: dirs first, key=\(sortKey), asc=\(sortAscending), total=\(sorted.count)")
        return sorted
    }

    // MARK: -
    func revealLogFileInFinder() {
        log.info(#function)
        // Use the user Logs folder: ~/Library/Logs/MiMiNavigator.log
        let fm = FileManager.default
        let logsDir = fm.urls(for: .libraryDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Logs", isDirectory: true)
        let logFileURL = logsDir.appendingPathComponent("MiMiNavigator.log", isDirectory: false)
        if fm.fileExists(atPath: logFileURL.path) {
            log.info("Revealing existing log file at: \(logFileURL.path)")
            NSWorkspace.shared.activateFileViewerSelecting([logFileURL])
            return
        }
        // Fallback: open/create the Logs directory if missing
        if !fm.fileExists(atPath: logsDir.path) {
            do {
                try fm.createDirectory(at: logsDir, withIntermediateDirectories: true)
                log.info("Created Logs directory at: \(logsDir.path)")
            } catch { log.error("Failed to create Logs directory: \(error.localizedDescription)") }
        }
        log.info("Opening Logs directory at: \(logsDir.path)")
        NSWorkspace.shared.activateFileViewerSelecting([logsDir])
    }

    // MARK: -
    func refreshLeftFiles() async {
        log.info(#function + " at path: \(leftPath.description)")
        let items = await scanner.fileLst.getLeftFiles()
        displayedLeftFiles = applySorting(items)
        if focusedPanel == .left, selectedLeftFile == nil {
            selectedLeftFile = displayedLeftFiles.first
            if let f = selectedLeftFile { log.info("Auto-selected left: \(f.nameStr)") }
        }
        log.info(" - Found \(displayedLeftFiles.count) left files (dirs first).")
    }

    // MARK: -
    func refreshRightFiles() async {
        log.info(#function + " at path: \(rightPath.description)")
        let items = await scanner.fileLst.getRightFiles()
        displayedRightFiles = applySorting(items)
        if focusedPanel == .right, selectedRightFile == nil {
            selectedRightFile = displayedRightFiles.first
            if let f = selectedRightFile { log.info("Auto-selected right: \(f.nameStr)") }
        }
        log.info(" - Found \(displayedRightFiles.count) right files (dirs first).")
    }

    // MARK: -
    func updatePath(_ path: String, for side: PanelSide) {
        log.info(#function + " at side: \(side) with path: \(path)")
        focusedPanel = side  // Set focus to the side; do not use binding ($)
        let currentPath = (side == .left ? leftPath : rightPath)
        guard toCanonical(from: currentPath) != toCanonical(from: path) else {
            log.info("\(#function) – skipping update: path unchanged (\(path))")
            return
        }
        log.info("\(#function) – updating path on side: \(side) to \(path)")
        switch side {
        case .left:
            leftPath = path
            selectedLeftFile = displayedLeftFiles.first

        case .right:
            rightPath = path
            selectedRightFile = displayedRightFiles.first
        }
    }

    // MARK: -
    func toCanonical(from path: String) -> String {
        if let url = URL(string: path), url.isFileURL {
            return url.standardized.resolvingSymlinksInPath().path
        } else {
            return (path as NSString).standardizingPath
        }
    }

    // MARK: -
    func saveBeforeExit() {
        log.info(#function)
        // Update snapshot in UserPreferences
        UserPreferences.shared.capture(from: self)
        UserPreferences.shared.save()
        // Persist last known paths
        UserDefaults.standard.set(leftPath, forKey: "lastLeftPath")
        UserDefaults.standard.set(rightPath, forKey: "lastRightPath")
        // Persist focused panel ("left" / "right")
        UserDefaults.standard.set(focusedPanel == .left ? "left" : "right", forKey: "lastFocusedPanel")
        // Persist last selected files (as URL)
        if let left = selectedLeftFile?.urlValue { UserDefaults.standard.set(left, forKey: "lastSelectedLeftFilePath") }
        if let right = selectedRightFile?.urlValue {
            UserDefaults.standard.set(right, forKey: "lastSelectedRightFilePath")
        }
        log.info("Application state saved before exit.")
    }
}

// MARK: - Initialization
extension AppState {

    // MARK: -
    func initialize() {
        log.info(#function)
        // 1) Load preferences
        UserPreferences.shared.load()
        UserPreferences.shared.apply(to: self)
        // 2) Остальная инициализация
        Task {
            await scanner.setLeftDirectory(pathStr: leftPath)
            await refreshLeftFiles()
            await scanner.setRightDirectory(pathStr: rightPath)
            await refreshRightFiles()
            // Restore selections and focus now that lists are populated
            restoreSelectionsAndFocus()
            await scanner.startMonitoring()
        }
    }
}
