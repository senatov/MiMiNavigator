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

    // MARK: - Actions
    func refreshLeftFiles() async {
        displayedLeftFiles = await scanner.fileLst.getLeftFiles()
    }
    // MARK:
    func refreshRightFiles() async {
        displayedRightFiles = await scanner.fileLst.getRightFiles()
    }
    // MARK:
    func selectFile(_ file: CustomFile, on side: PanelSide) {
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
    // MARK:
    func updatePath(_ path: String, on side: PanelSide) {
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
}
