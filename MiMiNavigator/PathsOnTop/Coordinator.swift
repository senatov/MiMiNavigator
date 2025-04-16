//
//  Coordinator.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 14.11.24.
//  Copyright © 2024 Senatov. All rights reserved.
//

import AppKit
import SwiftUI
import SwiftyBeaver

class Coordinator: NSObject {
    var onPathChanged: (String) -> Void

    init(onPathChanged: @escaping (String) -> Void) {
        self.onPathChanged = onPathChanged
    }

    @MainActor @objc func pathControlDidChange(_ sender: NSPathControl) {
        guard let url = sender.url else {
            log.warning("PathControl clicked, but no valid path was selected.")
            return
        }
        log.debug("PathControl clicked. New path selected: \(url.path)")
        onPathChanged(url.path)
    }
}
