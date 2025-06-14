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
        self.scanner = DualDirectoryScanner(appState: self)
    }
    
        // MARK:-
    func refreshLeftFiles() async {
        print("📂 AppState: refreshing LEFT files at path: \(leftPath)")
        displayedLeftFiles = await scanner.fileLst.getLeftFiles()
        print("📂 Found \(displayedLeftFiles.count) left files.")
    }
    
        // MARK:-
    func refreshRightFiles() async {
        print("📂 AppState: refreshing RIGHT files at path: \(rightPath)")
        displayedRightFiles = await scanner.fileLst.getRightFiles()
        print("📂 Found \(displayedRightFiles.count) right files.")
    }
    
        // MARK:-
    func pathURL(for side: PanelSide) -> URL? {
        let path: String
        switch side {
            case .left:
                path = leftPath
            case .right:
                path = rightPath
        }
        
        return URL(fileURLWithPath: path)
    }
    
    
        // MARK:-
    func refreshFiles() async {
        print("📂 AppState: refreshing ALL files")
        await refreshLeftFiles()
        await refreshRightFiles()
    }
    
        // MARK:-
    func selectedFile(for side: PanelSide) -> CustomFile? {
        switch side {
            case .left:
                return selectedLeftFile
            case .right:
                return selectedRightFile
        }
    }
    
        // MARK:-
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
    
    public func getSelectedDir() -> SelectedDir {
        return selectedDir
    }
}

extension AppState {
    
    public var focusedSideValue: PanelSide {
        focusedSide
    }
    
    public func initialize() {
        print("⚙️ AppState: initialize() called")
        Task {
            await scanner.setLeftDirectory(pathStr: leftPath)
            await refreshLeftFiles()
            await scanner.setRightDirectory(pathStr: rightPath)
            await refreshRightFiles()
            await scanner.startMonitoring()
        }
    }
}
