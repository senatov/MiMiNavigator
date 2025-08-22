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

    // MARK: -
    init(side: PanelSide = .left) {
        log.info(#function + " side: \(side))")
        if selectedFSEntity == nil {
            selectedFSEntity = CustomFile(path: "/tmp")
        }
    }
}
