//
// AppState.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 28.05.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import AppKit
import Combine
import Foundation

// MARK: -
@MainActor final class AppState: ObservableObject {
    @Published var displayedLeftFiles: [CustomFile] = []
    @Published var displayedRightFiles: [CustomFile] = []
    @Published var focusedPanel: PanelSide = .left { 
        didSet { 
            if oldValue != focusedPanel {
                syncSelectionWithFocus() 
            }
        } 
    }
    @Published var leftPath: String
    @Published var rightPath: String
    @Published var selectedDir: SelectedDir = .init()
    @Published var selectedLeftFile: CustomFile? { didSet { recordSelection(.left, file: selectedLeftFile) } }
    @Published var selectedRightFile: CustomFile? { didSet { recordSelection(.right, file: selectedRightFile) } }
    @Published var showFavTreePopup: Bool = false
    @Published var sortKey: SortKeysEnum = .name
    @Published var sortAscending: Bool = true
    private var isRestoringSelections = false
    private var suppressSync = false
    private var lastRecordedPathLeft: String?
    private var lastRecordedPathRight: String?
    let selectionsHistory = SelectionsHistory()
    let fileManager = FileManager.default
    var scanner: DualDirectoryScanner!
    private var cancellables = Set<AnyCancellable>()

    // MARK: -
    init() {
        log.info(#function + " - init AppState")
        leftPath = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first?.path ?? ""
        rightPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first?.path ?? ""
        scanner = DualDirectoryScanner(appState: self)

        leftPath = UserDefaults.standard.string(forKey: "lastLeftPath") ?? leftPath
        rightPath = UserDefaults.standard.string(forKey: "lastRightPath") ?? rightPath

        $selectedDir
            .compactMap { $0.selectedFSEntity?.urlValue.path }
            .sink { [weak self] newPath in
                guard let self = self else { return }
                if self.isRestoringSelections {
                    log.debug("History: sink skipped (restoring)")
                    return
                }
                if let last = self.selectionsHistory.last, last == newPath { return }
                self.selectionsHistory.add(newPath)
            }
            .store(in: &cancellables)

        if let raw = UserDefaults.standard.string(forKey: "lastFocusedPanel"), raw == "right" {
            focusedPanel = .right
        } else {
            focusedPanel = .left
        }
    }

    // MARK: - sel on side, clear opposite
    @MainActor
    func select(_ file: CustomFile, on panelSide: PanelSide) {
        log.debug("[SELECT-FLOW] 1️⃣ select(_:on:) CALLED on: <<\(panelSide)>> file: \(file.nameStr)")
        log.debug("[SELECT-FLOW] 1️⃣ BEFORE: L=\(selectedLeftFile?.nameStr ?? "nil") R=\(selectedRightFile?.nameStr ?? "nil")")
        
        switch panelSide {
            case .left:
                selectedLeftFile = file
                selectedRightFile = nil
                log.debug("[SELECT-FLOW] 1️⃣ SET: L=\(file.nameStr), cleared R")
            case .right:
                selectedRightFile = file
                selectedLeftFile = nil
                log.debug("[SELECT-FLOW] 1️⃣ SET: R=\(file.nameStr), cleared L")
        }
        
        log.debug("[SELECT-FLOW] 1️⃣ AFTER: L=\(selectedLeftFile?.nameStr ?? "nil") R=\(selectedRightFile?.nameStr ?? "nil")")
        
        suppressSync = true
        let oldFocus = focusedPanel
        focusedPanel = panelSide
        suppressSync = false
        
        log.debug("[SELECT-FLOW] 1️⃣ Focus changed: \(oldFocus) → \(focusedPanel)")
    }

    // MARK: -
    @MainActor
    func clearSelection(on panelSide: PanelSide) {
        log.debug(#function + " on: <<\(panelSide)>>")
        switch panelSide {
            case .left: selectedLeftFile = nil
            case .right: selectedRightFile = nil
        }
    }

    // MARK: -
    @MainActor
    func selectedFile(on panelSide: PanelSide) -> CustomFile? {
        log.debug(#function + " on: <<\(panelSide)>>")
        switch panelSide {
            case .left: return selectedLeftFile
            case .right: return selectedRightFile
        }
    }

    // MARK: -
    @MainActor
    func forceFocusSelection() { syncSelectionWithFocus() }

    // MARK: -
    private func canonicalPath(_ url: URL) -> String {
        return url.standardized.resolvingSymlinksInPath().path
    }

    // MARK: -
    private func restoreSelectionsAndFocus() {
        log.info(#function)
        isRestoringSelections = true
        defer { isRestoringSelections = false }
        let ud = UserDefaults.standard

        if let raw = ud.string(forKey: "lastFocusedPanel"), raw == "right" {
            focusedPanel = .right
        } else {
            focusedPanel = .left
        }

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
        syncSelectionWithFocus()
    }

    // MARK: -
    func toggleFocus() {
        focusedPanel = (focusedPanel == .left) ? .right : .left
        log.debug("TAB toggled focus to: \(focusedPanel)")
    }

    // MARK: -
    private func syncSelectionWithFocus() {
        guard !suppressSync, !isRestoringSelections else { return }
        log.debug("syncSelectionWithFocus: now \(focusedPanel)")
    }

    // MARK: -
    private func recordSelection(_ panelSide: PanelSide, file: CustomFile?) {
        guard let f = file else { return }
        let path = canonicalPath(f.urlValue)

        guard !isRestoringSelections else {
            log.debug("History: skipped (restoring)")
            return
        }

        switch panelSide {
            case .left:
                if lastRecordedPathLeft == path {
                    log.debug("History: skipped dupe for L (\(path))")
                    return
                }
                lastRecordedPathLeft = path

            case .right:
                if lastRecordedPathRight == path {
                    log.debug("History: skipped dupe for R (\(path))")
                    return
                }
                lastRecordedPathRight = path
        }
        log.debug("History[<<\(panelSide)]>> → \(path)")
        selectionsHistory.setCurrent(to: path)
    }

    // MARK: -
    func goBackInHistory() {
        if let p = selectionsHistory.previousPath() {
            log.debug("History: prev \(p)")
            selectPath(p)
        } else {
            log.debug("History: no prev path")
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
        isRestoringSelections = true
        defer { isRestoringSelections = false }
        let target = toCanonical(from: path)
        switch focusedPanel {
            case .left:
                if let f = displayedLeftFiles.first(where: { canonicalPath($0.urlValue) == target }) {
                    selectedLeftFile = f
                } else if let f = displayedRightFiles.first(where: { canonicalPath($0.urlValue) == target }) {
                    focusedPanel = .right
                    selectedRightFile = f
                } else {
                    log.debug("History: path not found: \(path)")
                }
            case .right:
                if let f = displayedRightFiles.first(where: { canonicalPath($0.urlValue) == target }) {
                    selectedRightFile = f
                } else if let f = displayedLeftFiles.first(where: { canonicalPath($0.urlValue) == target }) {
                    focusedPanel = .left
                    selectedLeftFile = f
                } else {
                    log.debug("History: path not found: \(path)")
                }
        }
    }

    // MARK: -
    func togglePanel() {
        focusedPanel = (focusedPanel == .left) ? .right : .left
        log.info(#function + " TAB toggled panel to: \(focusedPanel)")
    }

    // MARK: -
    func selectionMove(by step: Int) {
        log.debug(#function + " selectionMove(by: \(step)) | focus: \(focusedPanel)")
        let items = (focusedPanel == .left) ? displayedLeftFiles : displayedRightFiles
        guard !items.isEmpty else { return }

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
        log.debug("sel moved to idx \(nextIdx): \(next.nameStr)")
    }

    // MARK: -
    func selectionCopy() {
        log.debug(#function + "  focus: \(focusedPanel)")
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
            log.debug("copy skipped: no sel")
            return
        }
        guard let dstDirURL = pathURL(for: dstSide) else {
            log.error("copy failed: dst unavailable")
            return
        }
        let srcURL = file.urlValue
        let dstURL = dstDirURL.appendingPathComponent(srcURL.lastPathComponent)
        do {
            if FileManager.default.fileExists(atPath: dstURL.path) {
                log.debug("copy skipped: dst exists → \(dstURL.path)")
                return
            }
            try FileManager.default.copyItem(at: srcURL, to: dstURL)
            log.info("copied \(srcURL.lastPathComponent) → \(dstURL.path)")
            Task { @MainActor in
                if dstSide == .left { await refreshLeftFiles() } else { await refreshRightFiles() }
            }
        } catch {
            log.error("copy failed: \(error.localizedDescription)")
        }
    }

    // MARK: -
    func displayedFiles(for panelSide: PanelSide) -> [CustomFile] {
        log.debug(#function + " at side: <<\(panelSide)>>")
        switch panelSide {
            case .left: return displayedLeftFiles
            case .right: return displayedRightFiles
        }
    }

    // MARK: -
    func pathURL(for panelSide: PanelSide) -> URL? {
        log.debug(#function + "|side: <<\(panelSide)>>| paths: \(leftPath), \(rightPath)")
        let path: String
        switch panelSide {
            case .left: path = leftPath
            case .right: path = rightPath
        }
        return URL(fileURLWithPath: path)
    }

    // MARK: -
    @Sendable func refreshFiles() async {
        log.debug(#function)
        await refreshLeftFiles()
        await refreshRightFiles()
    }

    // MARK: -
    func updateSorting(key: SortKeysEnum? = nil, ascending: Bool? = nil) {
        log.debug("updateSorting(key: \(key ?? sortKey), asc: \(ascending ?? sortAscending), side: <<\(focusedPanel))>>")
        if let newKey = key { sortKey = newKey }
        if let newAsc = ascending { sortAscending = newAsc }

        if focusedPanel == .left {
            displayedLeftFiles = applySorting(displayedLeftFiles)
        } else {
            displayedRightFiles = applySorting(displayedRightFiles)
        }
        log.debug("updateSorting: key=\(sortKey), asc=\(sortAscending) on \(focusedPanel)")
    }

    // MARK: -
    private func isFolderLike(_ f: CustomFile) -> Bool {
        if f.isDirectory { return true }
        if f.isSymbolicDirectory { return true }

        let url = f.urlValue
        do {
            let rv = try url.resourceValues(forKeys: [.isSymbolicLinkKey])
            if rv.isSymbolicLink == true {
                let dst = url.resolvingSymlinksInPath()
                if let r2 = try? dst.resourceValues(forKeys: [.isDirectoryKey]), r2.isDirectory == true {
                    return true
                }
            }
        } catch {
            log.error("isFolderLike failed for \(url.path): \(error.localizedDescription)")
        }
        return false
    }

    // MARK: -
    func applySorting(_ items: [CustomFile]) -> [CustomFile] {
        log.debug(#function)
        let sorted = items.sorted { (a: CustomFile, b: CustomFile) in
            let aIsFolder = isFolderLike(a)
            let bIsFolder = isFolderLike(b)
            if aIsFolder != bIsFolder { return aIsFolder && !bIsFolder }

            switch sortKey {
                case .name:
                    let primary = a.nameStr.localizedCaseInsensitiveCompare(b.nameStr)
                    if primary != .orderedSame {
                        return sortAscending ? (primary == .orderedAscending) : (primary == .orderedDescending)
                    }
                    return a.nameStr.localizedCaseInsensitiveCompare(b.nameStr) == .orderedAscending

                case .date:
                    let da = a.modifiedDate ?? Date.distantPast
                    let db = b.modifiedDate ?? Date.distantPast
                    if da != db { return sortAscending ? (da < db) : (da > db) }
                    return a.nameStr.localizedCaseInsensitiveCompare(b.nameStr) == .orderedAscending

                case .size:
                    let sa: Int64 = a.sizeInBytes
                    let sb: Int64 = b.sizeInBytes
                    if sa != sb { return sortAscending ? (sa < sb) : (sa > sb) }
                    return a.nameStr.localizedCaseInsensitiveCompare(b.nameStr) == .orderedAscending
            }
        }
        log.debug("applySorting: dirs 1st, key=\(sortKey), asc=\(sortAscending), total=\(sorted.count)")
        return sorted
    }

    // MARK: -
    func revealLogFileInFinder() {
        log.debug(#function)
        let fm = FileManager.default
        let logsDir = fm.urls(for: .libraryDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Logs", isDirectory: true)
        let logFileURL = logsDir.appendingPathComponent("MiMiNavigator.log", isDirectory: false)
        if fm.fileExists(atPath: logFileURL.path) {
            log.debug("revealing log: \(logFileURL.path)")
            NSWorkspace.shared.activateFileViewerSelecting([logFileURL])
            return
        }

        if !fm.fileExists(atPath: logsDir.path) {
            do {
                try fm.createDirectory(at: logsDir, withIntermediateDirectories: true)
                log.debug("created Logs dir: \(logsDir.path)")
            } catch {
                log.error("failed to create Logs: \(error.localizedDescription)")
            }
        }
        log.debug("opening Logs dir: \(logsDir.path)")
        NSWorkspace.shared.activateFileViewerSelecting([logsDir])
    }

    // MARK: -
    func refreshLeftFiles() async {
        log.debug(#function + " at path: \(leftPath)")
        let items = await scanner.fileLst.getLeftFiles()
        displayedLeftFiles = applySorting(items)
        if focusedPanel == .left, selectedLeftFile == nil {
            selectedLeftFile = displayedLeftFiles.first
            if let f = selectedLeftFile { log.debug("auto-sel'd L: \(f.nameStr)") }
        }
        log.debug("found \(displayedLeftFiles.count) L files (dirs 1st)")
    }

    // MARK: -
    func refreshRightFiles() async {
        log.debug(#function + " at path: \(rightPath)")
        let items = await scanner.fileLst.getRightFiles()
        displayedRightFiles = applySorting(items)
        if focusedPanel == .right, selectedRightFile == nil {
            selectedRightFile = displayedRightFiles.first
            if let f = selectedRightFile { log.debug("auto-sel'd R: \(f.nameStr)") }
        }
        log.debug("found \(displayedRightFiles.count) R files (dirs 1st)")
    }

    // MARK: -
    func updatePath(_ path: String, for panelSide: PanelSide) {
        log.debug(#function + " at side: <<\(panelSide)>> path: \(path)")
        suppressSync = true
        focusedPanel = panelSide
        suppressSync = false
        let currentPath = (panelSide == .left ? leftPath : rightPath)
        guard toCanonical(from: currentPath) != toCanonical(from: path) else {
            log.debug("\(#function) – skip: path unchanged (\(path))")
            return
        }
        log.debug("\(#function) – updating path on <<\(panelSide)>> to \(path)")
        switch panelSide {
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
        log.debug(#function)
        UserPreferences.shared.capture(from: self)
        UserPreferences.shared.save()

        UserDefaults.standard.set(leftPath, forKey: "lastLeftPath")
        UserDefaults.standard.set(rightPath, forKey: "lastRightPath")
        UserDefaults.standard.set(focusedPanel == .left ? "left" : "right", forKey: "lastFocusedPanel")

        if let left = selectedLeftFile?.urlValue {
            UserDefaults.standard.set(left, forKey: "lastSelectedLeftFilePath")
        }
        if let right = selectedRightFile?.urlValue {
            UserDefaults.standard.set(right, forKey: "lastSelectedRightFilePath")
        }
        log.debug("app state saved before exit")
    }
}

// MARK: - init
extension AppState {
    func initialize() {
        log.debug(#function)
        UserPreferences.shared.load()
        UserPreferences.shared.apply(to: self)

        Task {
            await scanner.setLeftDirectory(pathStr: leftPath)
            await refreshLeftFiles()
            await scanner.setRightDirectory(pathStr: rightPath)
            await refreshRightFiles()
            restoreSelectionsAndFocus()
            await scanner.startMonitoring()
        }
    }
}
