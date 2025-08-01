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

@MainActor
final class AppState: ObservableObject {

    @Published var displayedLeftFiles: [CustomFile] = []
    @Published var displayedRightFiles: [CustomFile] = []
    @Published var focusedSide: PanelSide = .left
    @Published var leftPath: String
    @Published var rightPath: String
    @Published var selectedDir: SelectedDir = SelectedDir()
    @Published var selectedLeftFile: CustomFile?
    @Published var selectedRightFile: CustomFile?
    @Published var showFavTreePopup: Bool = false
    let selectionsHistory = SelectionsHistory()
    let fileManager = FileManager.default
    var scanner: DualDirectoryScanner!
    private var cancellables = Set<AnyCancellable>()


    // MARK: -
    init() {
        log.info(#function + " - Initializing AppState")
        self.leftPath = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first?.path ?? .empty
        self.rightPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first?.path ?? .empty
        self.scanner = DualDirectoryScanner(appState: self)

        // Restore saved paths
        self.leftPath = UserDefaults.standard.string(forKey: "lastLeftPath") ?? self.leftPath
        self.rightPath = UserDefaults.standard.string(forKey: "lastRightPath") ?? self.rightPath

        // Подписка на изменения selectedDir
        $selectedDir
            .compactMap { $0.selectedFSEntity?.urlValue.path }
            .sink { [weak self] newPath in
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
        log.info(#function + " at path: \(side)")
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

    // MARK: -
    func revealLogFileInFinder() {
        log.info(#function)
        // Path to the log file (update as needed)
        let logDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Logs/MiMiNavigator.log")
        NSWorkspace.shared.activateFileViewerSelecting([logDir])
    }


    // MARK: -
    func refreshLeftFiles() async {
        log.info(#function + " at path: \(leftPath.description)")
        displayedLeftFiles = await scanner.fileLst.getLeftFiles()
        log.debug(" - Found \(displayedLeftFiles.count) left files.")
    }


    // MARK: -
    func refreshRightFiles() async {
        log.info(#function + " at path: \(rightPath.description)")
        displayedRightFiles = await scanner.fileLst.getRightFiles()
        log.debug(" - Found \(displayedRightFiles.count) right files.")
    }


    // MARK: -
    func setSide(for side: PanelSide) {
        log.info(#function + " at side: \(side)")
        focusedSide = side
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
        focusedSide = side
        let currentPath = (side == .left ? leftPath : rightPath)
        guard toCanonical(from: currentPath) != toCanonical(from: path) else {
            log.debug("\(#function) – skipping update: path unchanged (\(path))")
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
        }
        else {
            return (path as NSString).standardizingPath
        }
    }


    // MARK: -
    func getSelectedDir() -> SelectedDir {
        log.info(#function + " at path: \(selectedDir.selectedFSEntity?.nameStr ?? "nil")")
        return selectedDir
    }


    // MARK: -
    func saveBeforeExit() {
        log.debug(#function)
        // Save left and right panel paths
        UserDefaults.standard.set(leftPath, forKey: "lastLeftPath")
        UserDefaults.standard.set(rightPath, forKey: "lastRightPath")
        // Save selected files if available
        if let left = selectedLeftFile {
            UserDefaults.standard.set(left.urlValue, forKey: "lastSelectedLeftFilePath")
        }
        if let right = selectedRightFile {
            UserDefaults.standard.set(right.urlValue, forKey: "lastSelectedRightFilePath")
        }
    }


}


// MARK: -
extension AppState {

    // MARK: -
    public var focusedSideValue: PanelSide {
        focusedSide
    }

    // MARK: -
    public func initialize() {
        log.info(#function)
        Task {
            await scanner.setLeftDirectory(pathStr: leftPath)
            await refreshLeftFiles()
            await scanner.setRightDirectory(pathStr: rightPath)
            await refreshRightFiles()
            await scanner.startMonitoring()
        }
    }
}
