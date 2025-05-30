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
public final class AppState: ObservableObject {

    // MARK: - Path & Files
    @Published var leftPath: String = FileManager.default.homeDirectoryForCurrentUser.path
    @Published var rightPath: String = FileManager.default.applicationSupportDirectory.path

    @Published var displayedLeftFiles: [CustomFile] = []
    @Published var displayedRightFiles: [CustomFile] = []

    // MARK: - Selection & Focus
    @Published var selectedLeftFile: CustomFile?
    @Published var selectedRightFile: CustomFile?
    @Published var focusedSide: PanelSide = .left
    @Published var selectedDir: SelectedDir = SelectedDir()

    // MARK: - Dependencies
    let model: DirectoryModel
    lazy var scanner: DualDirectoryScanner = DualDirectoryScanner(appState: self)

    // MARK: - Init
    init() {
        let model = DirectoryModel()
        self.model = model
        self.leftPath = model.leftDirectory.path
        self.rightPath = model.rightDirectory.path
    }

    // MARK: - File Refreshing
    public func refreshLeftFiles() async {
        await scanner.setLeftDirectory(pathStr: leftPath)
    }

    // MARK: -
    public func refreshRightFiles() async {
        await scanner.setRightDirectory(pathStr: rightPath)
    }

    // MARK: - File Selection
    public func selectFile(_ file: CustomFile, on side: PanelSide) {
        log.info("selectFile(\(file.pathStr)) on \(side)")
        switch side {
        case .left:
            selectedLeftFile = file
            leftPath = file.pathStr
        case .right:
            selectedRightFile = file
            rightPath = file.pathStr
        }
        focusedSide = side
    }

    // MARK: - Path Updating
    public func updatePath(_ path: String, on side: PanelSide) {
        log.info("updatePath(\(path)) on \(side)")
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

    // MARK: - Convenience Accessors
    public func selectedFile(for side: PanelSide) -> CustomFile? {
        log.info("selectedFile(for: \(side))")
        switch side {
        case .left:
            return selectedLeftFile
        case .right:
            return selectedRightFile
        }
    }

    // MARK: -
    public func path(for side: PanelSide) -> String {
        log.info("path(for: \(side))")
        switch side {
        case .left:
            return leftPath
        case .right:
            return rightPath
        }
    }

    // MARK: -
    public func pathURL(for side: PanelSide) -> URL? {
        let pathStr = path(for: side)
        return URL(fileURLWithPath: pathStr)
    }

    @MainActor
    func refreshFiles(for side: PanelSide) async {
        log.info("refreshFiles(for: \(side))")
        switch side {
        case .left:
            await refreshLeftFiles()
        case .right:
            await refreshRightFiles()
        }
    }
}

extension PanelSide {
    var opposite: PanelSide {
        switch self {
        case .left:
            return .left
        case .right:
            return .right
        }
    }
}
