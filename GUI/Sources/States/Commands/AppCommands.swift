//
// AppCommands.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 27.09.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import AppKit
import SwiftUI

struct AppCommands: Commands {
    let appState: AppState

    var body: some Commands {
        CommandMenu("Panels / Navigation") {
            Button("Toggle Panel Focus (⌘⌥T)") {
                log.debug("KB: Cmd+Opt+T → toggle panel")
                appState.toggleFocus()
            }
            .keyboardShortcut("t", modifiers: [.command, .option])

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
            .keyboardShortcut("c", modifiers: [.command])
        }
        CommandGroup(replacing: .appTermination) {
            Button("Exit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut(.escape, modifiers: [.option])
        }
    }
}
