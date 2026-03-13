//
//  SettingsCommands.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 13.03.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//  Description: SwiftUI Commands additions for MiMiNavigatorApp.
//               Extracted from MiMiNavigatorApp.swift.

import SwiftUI

// MARK: - SettingsCommands
/// Adds Settings… (⌘,) before the system .appSettings group.
struct SettingsCommands: Commands {
    var body: some Commands {
        CommandGroup(before: .appSettings) {
            Button("Settings…") {
                SettingsCoordinator.shared.toggle()
            }
            .keyboardShortcut(",", modifiers: .command)
        }
    }
}
