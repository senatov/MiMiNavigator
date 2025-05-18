//
//  SelectedDir.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 09.05.25.
//  Copyright © 2025 Senatov. All rights reserved.
//

import Combine
import Foundation

// MARK: - PanelSide Enum
/// Represents the panel side (left or right) in the UI
public enum PanelSide: String, Codable, CaseIterable {
    case left
    case right
}

// MARK: - SelectedDir ViewModel
/// Encapsulates the selected file system entity and its associated panel side
public class SelectedDir: ObservableObject, CustomStringConvertible {
    @Published public var selectedFSEntity: CustomFile
    @Published public var side: PanelSide

    // MARK: -
    public var description: String {
        "description"
    }

    // MARK: - Initializes with default path and panel side
    public init(initialPath: String = "~/Documents", side: PanelSide = .left) {
        self.selectedFSEntity = CustomFile(path: initialPath)
        self.side = side
    }

    // MARK: - Initializes from an existing SelectedDir instance
    public init(
        selectedDir: SelectedDir = SelectedDir(initialPath: "~/Documents"),
        side: PanelSide = .left
    ) {
        self.selectedFSEntity = selectedDir.selectedFSEntity
        self.side = side
    }

    // MARK: -
    public func change(initialPath: String = "~/Documents", side: PanelSide = .left) {
        self.selectedFSEntity = CustomFile(path: initialPath)
        self.side = side
    }
}
