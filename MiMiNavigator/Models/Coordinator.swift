//
//  Coordinator.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 14.11.24.
//  Copyright © 2024 Senatov. All rights reserved.
//

import AppKit
import SwiftUI

class Coordinator: NSObject {
    var onPathSelected: (String) -> Void

    init(onPathSelected: @escaping (String) -> Void) {
        self.onPathSelected = onPathSelected
    }

    @MainActor @objc func pathControlDidChange(_ sender: NSPathControl) {
        if let url = sender.url {
            onPathSelected(url.path)
        }
    }
}
