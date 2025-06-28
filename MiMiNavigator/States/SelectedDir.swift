//
//  SelectedDir.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 09.05.25.
//  Copyright © 2025 Senatov. All rights reserved.
//

import Combine
import Foundation

// MARK: - Encapsulates the selected file system entity and its associated panel side
public class SelectedDir: ObservableObject {
    @Published public var selectedFSEntity: CustomFile?
    @Published public var side: PanelSide

    // MARK: - Initializes with default path and panel side
    public init(initialPath: String = "/Users", side: PanelSide = .left) {
        log.info("# SelectedDir.init(initialPath: \(initialPath), side: \(side))")
        self.selectedFSEntity = CustomFile(path: initialPath)
        self.side = side
    }

    // MARK: -
    public init(side: PanelSide = .left) {
        log.info(#function + " side: \(side))")
        self.side = side
        if selectedFSEntity == nil {
            selectedFSEntity = CustomFile(path: "/tmp")
        }
    }

    // MARK: - Initializes from an existing SelectedDir instance
    public init(selectedDir: SelectedDir = SelectedDir(initialPath: "/Users/senat"), side: PanelSide = .left) {
        log.info(#function + "selectedDir: \(selectedDir), side: \(side))")
        self.selectedFSEntity = selectedDir.selectedFSEntity
        self.side = side
    }

  
    
    // MARK: -
    public func change(initialPath: String = "/Users/senat/Downloads", side: PanelSide = .left) {
        log.info("#function + (initialPath: \(initialPath), side: \(side))")
        self.selectedFSEntity = CustomFile(path: initialPath)
        self.side = side
    }
}
