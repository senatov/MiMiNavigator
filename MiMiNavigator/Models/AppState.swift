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
        displayedLeftFiles = await scanner.fileLst.getLeftFiles()
    }

    public func refreshRightFiles() async {
        displayedRightFiles = await scanner.fileLst.getRightFiles()
    }

    // MARK: - File Selection
    public func selectFile(_ file: CustomFile, on side: PanelSide) {
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
        switch side {
        case .left:
            return selectedLeftFile
        case .right:
            return selectedRightFile
        }
    }

    public func path(for side: PanelSide) -> String {
        switch side {
        case .left:
            return leftPath
        case .right:
            return rightPath
        }
    }

    public func pathURL(for side: PanelSide) -> URL? {
        let pathStr = path(for: side)
        return URL(fileURLWithPath: pathStr)
    }

    @MainActor
    func refreshFiles(for side: PanelSide) async {
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
            return .right
        case .right:
            return .left
        }
    }
}
