// HotKeyDefaults.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 10.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Factory defaults and aliases for keyboard shortcuts.

import Foundation

// MARK: - Default Bindings Factory
/// Provides the factory-default hotkey bindings.
/// These are used on first launch and when the user clicks "Reset to Defaults".
enum HotKeyDefaults {

    /// Total Commander/Norton Commander defaults, excluding macOS-reserved shortcuts.
    static let bindings: [HotKeyBinding] = HotKeyPresets.totalCommander

    /// Lookup dictionary for quick access (one primary binding per action)
    static let bindingsByAction: [HotKeyAction: HotKeyBinding] = {
        Dictionary(uniqueKeysWithValues: bindings.map { ($0.action, $0) })
    }()

    /// Additional keyCode aliases: extra keys that trigger the same action
    /// without replacing the primary binding shown in Settings.
    /// Format: (keyCode, modifiers) → action
    static let aliases: [(keyCode: UInt16, modifiers: HotKeyModifiers, action: HotKeyAction)] = [
        (0x75, .none, .deleteFile),       // Fwd-Delete → same as F8
        (0x08, .control, .clipboardCopy), // Ctrl+C → clipboard copy (Windows style)
        (0x07, .control, .clipboardCut),  // Ctrl+X → clipboard cut (Windows style)
        (0x09, .control, .clipboardPaste),// Ctrl+V → clipboard paste (Windows style)
    ]
}
