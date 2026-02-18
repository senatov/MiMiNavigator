// HotKeyDefaults.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 10.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Factory defaults for all keyboard shortcuts — Total Commander layout

import Foundation

// MARK: - Default Bindings Factory
/// Provides the factory-default hotkey bindings.
/// These are used on first launch and when the user clicks "Reset to Defaults".
enum HotKeyDefaults {

    /// All default bindings — Total Commander-inspired layout
    static let bindings: [HotKeyBinding] = [
        // ── File Operations ──
        HotKeyBinding(action: .viewFile,         keyCode: 0x63, modifiers: .none),         // F3
        HotKeyBinding(action: .editFile,         keyCode: 0x76, modifiers: .none),         // F4
        HotKeyBinding(action: .copyFile,         keyCode: 0x60, modifiers: .none),         // F5
        HotKeyBinding(action: .moveFile,         keyCode: 0x61, modifiers: .none),         // F6
        HotKeyBinding(action: .newFolder,        keyCode: 0x62, modifiers: .none),         // F7
        HotKeyBinding(action: .deleteFile,       keyCode: 0x64, modifiers: .none),         // F8
        HotKeyBinding(action: .deleteFile,       keyCode: 0x75, modifiers: .none),         // Fwd-Delete

        // ── Navigation ──
        HotKeyBinding(action: .togglePanelFocus, keyCode: 0x30, modifiers: .none),         // Tab
        HotKeyBinding(action: .moveUp,           keyCode: 0x7E, modifiers: .none),         // ↑
        HotKeyBinding(action: .moveDown,         keyCode: 0x7D, modifiers: .none),         // ↓
        HotKeyBinding(action: .openSelected,     keyCode: 0x24, modifiers: .none),         // Return
        HotKeyBinding(action: .parentDirectory,  keyCode: 0x33, modifiers: .none),         // Backspace
        HotKeyBinding(action: .refreshPanels,    keyCode: 0x0F, modifiers: .command),      // ⌘R

        // ── Selection (Total Commander style) ──
        HotKeyBinding(action: .toggleMark,       keyCode: 0x72, modifiers: .none),         // Insert
        HotKeyBinding(action: .markByPattern,    keyCode: 0x45, modifiers: .none),         // Num+
        HotKeyBinding(action: .unmarkByPattern,  keyCode: 0x4E, modifiers: .none),         // Num−
        HotKeyBinding(action: .invertMarks,      keyCode: 0x43, modifiers: .none),         // Num×
        HotKeyBinding(action: .markAll,          keyCode: 0x00, modifiers: .command),      // ⌘A
        HotKeyBinding(action: .unmarkAll,        keyCode: 0x35, modifiers: .none),         // Escape (when marks exist)
        HotKeyBinding(action: .markSameExtension, keyCode: 0x00, modifiers: [.command, .shift]), // ⌘⇧A

        // ── Tabs ──
        HotKeyBinding(action: .newTab,           keyCode: 0x11, modifiers: .command),      // ⌘T
        HotKeyBinding(action: .closeTab,         keyCode: 0x0D, modifiers: .command),      // ⌘W
        HotKeyBinding(action: .nextTab,          keyCode: 0x1E, modifiers: [.command, .shift]), // ⌘⇧]
        HotKeyBinding(action: .prevTab,          keyCode: 0x21, modifiers: [.command, .shift]), // ⌘⇧[

        // ── Search ──
        HotKeyBinding(action: .findFiles,        keyCode: 0x62, modifiers: .option),       // ⌥F7
        
        // ── Application ──
        HotKeyBinding(action: .toggleHiddenFiles, keyCode: 0x2F, modifiers: .command),     // ⌘.
        HotKeyBinding(action: .openSettings,     keyCode: 0x2B, modifiers: .command),      // ⌘,
        HotKeyBinding(action: .exitApp,          keyCode: 0x76, modifiers: .option),       // ⌥F4
    ]

    /// Lookup dictionary for quick access
    static let bindingsByAction: [HotKeyAction: HotKeyBinding] = {
        Dictionary(uniqueKeysWithValues: bindings.map { ($0.action, $0) })
    }()
}
