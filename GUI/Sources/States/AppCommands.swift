//
//  AppCommands.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 27.09.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import SwiftUI

struct AppCommands: Commands {
    let coordinator: SelectionCoordinator

    var body: some Commands {
        CommandMenu("Panels / Navigation") {
            Button("Toggle Panel Focus") {
                coordinator.togglePanel(shift: false)
            }
            .keyboardShortcut(.tab, modifiers: [])

            Button("Move Up") {
                coordinator.moveSelection(step: -1)
            }
            .keyboardShortcut(.upArrow, modifiers: [])

            Button("Move Down") {
                coordinator.moveSelection(step: 1)
            }
            .keyboardShortcut(.downArrow, modifiers: [])

            Button("Copy") {
                coordinator.copySelection()
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
