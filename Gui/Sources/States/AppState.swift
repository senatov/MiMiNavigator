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
@MainActor
final class AppState: ObservableObject {
    @Published var displayedLeftFiles: [CustomFile] = []
    @Published var displayedRightFiles: [CustomFile] = []
    @Published var focusedPanel: PanelSide = .left
    @Published var leftPath: String
    @Published var rightPath: String
    @Published var selectedDir: SelectedDir = .init()
    @Published var selectedLeftFile: CustomFile?
    @Published var selectedRightFile: CustomFile?
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
        self.leftPath = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first?.path ?? ""
        self.rightPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first?.path ?? ""
        self.scanner = DualDirectoryScanner(appState: self)
        // Restore saved paths
        self.leftPath = UserDefaults.standard.string(forKey: "lastLeftPath") ?? leftPath
        self.rightPath = UserDefaults.standard.string(forKey: "lastRightPath") ?? rightPath
        // Подписка на изменения selectedDir
        $selectedDir.compactMap { $0.selectedFSEntity?.urlValue.path }.sink { [weak self] newPath in
            self?.selectionsHistory.add(newPath)
        }
        .store(in: &cancellables)
    }

    // MARK: - AppState extension for displayedFiles
    func displayedFiles(for side: PanelSide) -> [CustomFile] {
        log.info(#function + " at side: \(side)")
        switch side {
        case .left:
            return displayedLeftFiles
        case .right:
            return displayedRightFiles
        }
    }

    // MARK: -
    func pathURL(for side: PanelSide) -> URL? {
        log.info(#function + "|side: \(side)" + "| paths: \(leftPath),| \(rightPath)")
        let path: String
        switch side {
        case .left:
            path = leftPath
        case .right:
            path = rightPath
        }
        return URL(fileURLWithPath: path)
    }

    // MARK: -
    @Sendable
    func refreshFiles() async {
        log.info(#function)
        await refreshLeftFiles()
        await refreshRightFiles()
    }

    // MARK: - Sorting control
    func updateSorting(key: SortKeysEnum? = nil, ascending: Bool? = nil) {
        log.info("updateSorting(key: \(key ?? sortKey), asc: \(ascending ?? sortAscending), side: \(focusedPanel))")
        if let newKey = key {
            sortKey = newKey
        }
        if let newAsc = ascending {
            sortAscending = newAsc
        }
        // Resort currently displayed files
        if focusedPanel == .left {
            displayedLeftFiles = applySorting(displayedLeftFiles)
        } else {
            displayedRightFiles = applySorting(displayedRightFiles)
        }
        log.info("updateSorting: key=\(sortKey), asc=\(sortAscending) on \(focusedPanel) side")
    }

    /// English: Treat real directories and symlinks-to-directories as folder-like. Bundles treated as files by default.
    private func isFolderLike(_ f: CustomFile) -> Bool {
        if f.isDirectory {
            return true
        }
        if f.isSymbolicDirectory {
            return true
        }
        // Fallback via URL if flags are not set in the model
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
            if aIsFolder != bIsFolder {
                return aIsFolder && !bIsFolder
            }
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
                let da: Date = (a.modifiedDate as Date?) ?? Date.distantPast
                let db: Date = (b.modifiedDate as Date?) ?? Date.distantPast
                if da != db {
                    return sortAscending ? (da < db) : (da > db)
                }
                // Tie-breaker by name (ascending)
                return a.nameStr.localizedCaseInsensitiveCompare(b.nameStr) == .orderedAscending

            case .size:
                let sa: Int64 = ((a.sizeInBytes as Any) as? Int64) ?? Int64(((a.sizeInBytes as Any) as? Int) ?? 0)
                let sb: Int64 = ((b.sizeInBytes as Any) as? Int64) ?? Int64(((b.sizeInBytes as Any) as? Int) ?? 0)
                if sa != sb {
                    return sortAscending ? (sa < sb) : (sa > sb)
                }
                // Tie-breaker by name (ascending)
                return a.nameStr.localizedCaseInsensitiveCompare(b.nameStr) == .orderedAscending
            }
        }
        log.debug("applySorting: dirs first, key=\(sortKey), asc=\(sortAscending), total=\(sorted.count)")
        return sorted
    }

    // MARK: -
    func revealLogFileInFinder() {
        log.info(#function)
        // English comment: Use the user Logs folder: ~/Library/Logs/MiMiNavigator.log
        let fm = FileManager.default
        let logsDir = fm.urls(for: .libraryDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("Logs", isDirectory: true)
        let logFileURL = logsDir.appendingPathComponent("MiMiNavigator.log", isDirectory: false)
        if fm.fileExists(atPath: logFileURL.path) {
            log.debug("Revealing existing log file at: \(logFileURL.path)")
            NSWorkspace.shared.activateFileViewerSelecting([logFileURL])
            return
        }
        // Fallback: open/create the Logs directory if missing
        if !fm.fileExists(atPath: logsDir.path) {
            do {
                try fm.createDirectory(at: logsDir, withIntermediateDirectories: true)
                log.debug("Created Logs directory at: \(logsDir.path)")
            } catch {
                log.error("Failed to create Logs directory: \(error.localizedDescription)")
            }
        }
        log.debug("Opening Logs directory at: \(logsDir.path)")
        NSWorkspace.shared.activateFileViewerSelecting([logsDir])
    }

    // MARK: -
    func refreshLeftFiles() async {
        log.info(#function + " at path: \(leftPath.description)")
        let items = await scanner.fileLst.getLeftFiles()
        displayedLeftFiles = applySorting(items)
        log.debug(" - Found \(displayedLeftFiles.count) left files (dirs first).")
    }

    // MARK: -
    func refreshRightFiles() async {
        log.info(#function + " at path: \(rightPath.description)")
        let items = await scanner.fileLst.getRightFiles()
        displayedRightFiles = applySorting(items)
        log.debug(" - Found \(displayedRightFiles.count) right files (dirs first).")
    }

    // MARK: -
    func setSideFile(for side: PanelSide) -> CustomFile? {
        log.info(#function + " at side: \(side)")
        switch side {
        case .left:
            return selectedLeftFile
        case .right:
            return selectedRightFile
        }
    }

    // MARK: -
    func updatePath(_ path: String, for side: PanelSide) {
        log.debug(#function + " at side: \(side) with path: \(path)")
        focusedPanel = side // Set focus to the side; do not use binding ($)
        let currentPath = (side == .left ? leftPath : rightPath)
        guard toCanonical(from: currentPath) != toCanonical(from: path) else {
            log.debug(
                "\(#function) – skipping update: path unchanged (\(path))"
            )
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
    func getSelectedDir() -> SelectedDir {
        log.info(
            #function
                + " at path: \(selectedDir.selectedFSEntity?.nameStr ?? "nil")"
        )
        return selectedDir
    }

    // MARK: -
    func saveBeforeExit() {
        log.debug(#function)
        // Update snapshot in UserPreferences
        UserPreferences.shared.capture(from: self)
        UserPreferences.shared.save()
        // Optional: keep legacy direct UserDefaults writes if needed
        UserDefaults.standard.set(leftPath, forKey: "lastLeftPath")
        UserDefaults.standard.set(rightPath, forKey: "lastRightPath")
        if let left = selectedLeftFile {
            UserDefaults.standard.set(left.urlValue, forKey: "lastSelectedLeftFilePath")
        }
        if let right = selectedRightFile {
            UserDefaults.standard.set(right.urlValue, forKey: "lastSelectedRightFilePath")
        }
        log.info("Application state saved before exit.")
    }
}

// MARK: -
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
            await scanner.startMonitoring()
        }
    }
}
