//
//  AppState.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 28.05.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import Combine
import Foundation

@MainActor
final class AppState: ObservableObject {
    // MARK: - Path & Files
    @Published var showFavTreePopup: Bool = false
    @Published var leftPath: String
    @Published var rightPath: String
    @Published var displayedLeftFiles: [CustomFile] = []
    @Published var displayedRightFiles: [CustomFile] = []
    // MARK: - Selection & Focus
    @Published var selectedLeftFile: CustomFile?
    @Published var selectedRightFile: CustomFile?
    @Published var focusedSide: PanelSide = .left
    @Published var selectedDir: SelectedDir = SelectedDir()
    // MARK: - Dependencies
    let model: DirectoryModel = DirectoryModel()
    var scanner: DualDirectoryScanner!


    // MARK: - Init
    init() {
        self.leftPath = model.leftDirectory.path
        self.rightPath = model.rightDirectory.path
        self.scanner = DualDirectoryScanner(appState: self)
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
    func refreshFiles() async {
        log.info(#function)
        await refreshLeftFiles()
        await refreshRightFiles()
    }


    // MARK: -
    func refreshLeftFiles() async {
        log.info(#function + " at path: \(leftPath)")
        displayedLeftFiles = await scanner.fileLst.getLeftFiles()
        print(" - Found \(displayedLeftFiles.count) left files.")
    }


    // MARK: -
    func refreshRightFiles() async {
        log.info(#function + " at path: \(rightPath)")
        displayedRightFiles = await scanner.fileLst.getRightFiles()
        print(" - Found \(displayedRightFiles.count) right files.")
    }


    // MARK: -
    func selectedFile(for side: PanelSide) -> CustomFile? {
        log.info(#function)
        switch side {
            case .left:
                return selectedLeftFile
            case .right:
                return selectedRightFile
        }
    }


    // MARK: -
    func updatePath(_ path: String, on side: PanelSide) {
        log.info(#function)
        switch side {
            case .left:
                leftPath = path
                selectedLeftFile = nil
            case .right:
                rightPath = path
                selectedRightFile = nil
        }
        focusedSide = side
    }


    // MARK: -
    public func getSelectedDir() -> SelectedDir {
        return selectedDir
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
