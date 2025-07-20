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
class SelectedDir: ObservableObject {
    @Published var selectedFSEntity: CustomFile?
    @Published var side: PanelSide


    // MARK: -
    init(side: PanelSide = .left) {
        log.info(#function + " side: \(side))")
        self.side = side
        if selectedFSEntity == nil {
            selectedFSEntity = CustomFile(path: "/tmp")
        }
    }
}
