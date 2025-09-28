//
//  AppCommands.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 27.09.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import SwiftUI

struct AppCommands: Commands {
    let appState: AppState

    var body: some Commands {
        CommandMenu("Panels / Navigation") {
            Button("Toggle Panel Focus") {
                // Use AppState passthrough to avoid Binding traps and ensure same instance
                log.debug("KB: Tab → toggle panel")
                appState.togglePanel()
            }
            .keyboardShortcut(.tab, modifiers: [])

            Button("Toggle Panel Focus (Ctrl+Tab)") {
                // Diagnostic alternate shortcut to avoid system focus traversal swallowing Tab
                log.debug("KB: Ctrl+Tab → toggle panel (diagnostic)")
                appState.togglePanel()
            }
            .keyboardShortcut(.tab, modifiers: [.control])

            Button("Move Up") {
                appState.selectionMove(by: -1)
            }
            .keyboardShortcut(.upArrow, modifiers: [])

            Button("Move Down") {
                appState.selectionMove(by: 1)
            }
            .keyboardShortcut(.downArrow, modifiers: [])

            Button("Copy") {
                appState.selectionCopy()
            }
            .keyboardShortcut("c", modifiers: [.command])  // пример: ⌘C для Copy
        }
        CommandGroup(replacing: .appTermination) {
            Button("Exit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut(.escape, modifiers: [.option])
        }
    }
}
