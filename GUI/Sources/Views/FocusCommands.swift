//
//  FocusCommands.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 28.09.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

// Comments in English only
import SwiftUI

struct FocusCommands: Commands {
    @EnvironmentObject var appState: AppState
    @Environment(\.openWindow) private var openWindow  // if you use multiple windows

    var body: some Commands {
        CommandMenu("Panels") {
            Button("Toggle Panel Focus") {
                // Your coordinator call:
                appState.togglePanel()
                log.debug("KB: Tab → toggle panel")
            }
            .keyboardShortcut(.tab, modifiers: [])   // Tab

            Button("Toggle Panel Focus (Reverse)") {
                appState.togglePanel()
                log.debug("KB: Shift+Tab → toggle panel (reverse)")
            }
            .keyboardShortcut(.tab, modifiers: [.shift]) // Shift+Tab
        }
    }
}
