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
    var onPathSelected: (String) -> Void
        //DualDirectoryScanner.
        init(onPathSelected: @escaping (String) -> Void) {
            self.onPathSelected = onPathSelected
    }

    @MainActor @objc func pathControlDidChange(_ sender: NSPathControl) {
        sender.isEditable = true  // Делаем NSPathControl редактируемым
        if let url = sender.url {
            log.debug("PathControl clicked. New path selected: \(url.path)")
            onPathSelected(url.path)
        } else {
            log.warning("PathControl clicked but no valid path was selected.")
        }
    }
}
