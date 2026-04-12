//
//  ConvertMediaWindowDelegate.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 12.04.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import AppKit
import FileModelKit
import SwiftUI

final class ConvertMediaWindowDelegate: NSObject, NSWindowDelegate {
    @MainActor static let shared = ConvertMediaWindowDelegate()

    func windowWillClose(_ notification: Notification) {
        Task { @MainActor in
            ConvertMediaCoord.shared.windowDidClose()
        }
    }
}
