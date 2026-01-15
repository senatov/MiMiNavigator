// TerminalScriptConfig.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 28.09.2024.
//  Copyright © 2024 Senatov. All rights reserved.
//

import Foundation

// MARK: - Configuration for terminal AppleScript
enum TerminalScriptConfig {
    static let scriptName = "OpenTerminal"
    static let scriptExtension = "scpt"
    static let scriptSubdirectory = "Gui/OSScript"
    static let unknownBundleURL = "(unknown bundle resourceURL)"
}

// MARK: - Legacy alias for backward compatibility
typealias ScrCnst = TerminalScriptConfig
