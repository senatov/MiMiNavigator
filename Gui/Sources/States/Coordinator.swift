//
//  Coordinator.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 13.08.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import AppKit
import SwiftUI
import SwiftyBeaver

// MARK: -
class Coordinator: NSObject {
    let onClick: (() -> Void)?

    // MARK: -
    init(onClick: (() -> Void)?) {
        log.info(#function + "Creating Coordinator with onClick handler")
        self.onClick = onClick
    }

    // MARK: -
    @objc func handleClick() {
        log.debug("BlurView clicked")
        onClick?()
    }
}
