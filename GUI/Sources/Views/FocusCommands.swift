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
    let appState: AppState  // direct reference

    // MARK: -
    init(appState: AppState) {
        self.appState = appState
    }

    // MARK: -
    var body: some Commands {
        CommandMenu("Panels / Navigation") {
            Button("Toggle Panel Focus") { appState.togglePanel() }
                .keyboardShortcut(.tab, modifiers: [])
            Button("Toggle Panel Focus (Ctrl+Tab)") { appState.togglePanel() }
                .keyboardShortcut(.tab, modifiers: [.control])
            Button("Move Up") { appState.selectionMove(by: -1) }
                .keyboardShortcut(.upArrow, modifiers: [])
            Button("Move Down") { appState.selectionMove(by: 1) }
                .keyboardShortcut(.downArrow, modifiers: [])
            Button("Copy") { appState.selectionCopy() }
                .keyboardShortcut("c", modifiers: [.command])
        }
    }
}
