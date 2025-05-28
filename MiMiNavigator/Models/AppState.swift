//
//  SharedState.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 28.05.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import Combine
import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var leftPath: String
    @Published var rightPath: String
    @Published var displayedLeftFiles: [CustomFile]
    @Published var displayedRightFiles: [CustomFile]
    @Published var selectedLeftFile: CustomFile?
    @Published var selectedRightFile: CustomFile?
    @Published var selectedDir: SelectedDir

    let model: DirectoryModel
    lazy var scanner = DualDirectoryScanner(appState: self)

    // MARK: -
    init() {
        let model = DirectoryModel()
        self.model = model
        self.leftPath = model.leftDirectory.path
        self.rightPath = model.rightDirectory.path
        self.displayedLeftFiles = []
        self.displayedRightFiles = []
        self.selectedDir = SelectedDir()
        // scanner will be initialized lazily after init
    }

    // MARK: -
    func refreshLeftFiles() async {
        displayedLeftFiles = await scanner.fileLst.getLeftFiles()
    }

    // MARK: -
    func refreshRightFiles() async {
        displayedRightFiles = await scanner.fileLst.getRightFiles()
    }
}
