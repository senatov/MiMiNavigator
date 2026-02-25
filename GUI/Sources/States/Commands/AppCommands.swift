//
// AppCommands.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 27.09.2025.
//  Copyright © 2025-2026 Senatov. All rights reserved.
// Description: Minimal system menu bar — utility app, no duplication with in-window menu.

import AppKit
import SwiftUI

struct AppCommands: Commands {
    let appState: AppState

    var body: some Commands {
        // Replace default "New Window" etc. with nothing
        CommandGroup(replacing: .newItem) {}

        // Replace Help menu — keep empty (we have our own)
        CommandGroup(replacing: .help) {}

        // Replace Quit with our own exit
        CommandGroup(replacing: .appTermination) {
            Button("Quit MiMiNavigator") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
    }
}
