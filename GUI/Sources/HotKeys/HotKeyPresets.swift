// HotKeyPresets.swift
// MiMiNavigator
//
// Copyright © 2024-2026 Senatov. All rights reserved.
// Description: Predefined shortcut sets — Finder style and Total Commander style.

import Foundation

// MARK: - HotKeyPreset
enum HotKeyPreset: String, CaseIterable, Identifiable {
    case totalCommander = "Total Commander"
    case finder = "Finder"
    case custom = "Custom"
    
    var id: String { rawValue }
    var displayName: String { rawValue }
    
    var icon: String {
        switch self {
        case .totalCommander: return "rectangle.split.2x1"
        case .finder: return "folder"
        case .custom: return "slider.horizontal.3"
        }
    }
}

// MARK: - HotKeyPresets
enum HotKeyPresets {
    
    // ═══════════════════════════════════════════════════════════════════
    // MARK: - Total Commander Layout (F-keys, Insert for marking)
    // ═══════════════════════════════════════════════════════════════════
    static let totalCommander: [HotKeyBinding] = [
        // ── File Operations (F3-F8) ──
        HotKeyBinding(action: .viewFile,         keyCode: 0x63, modifiers: .none),         // F3
        HotKeyBinding(action: .editFile,         keyCode: 0x76, modifiers: .none),         // F4
        HotKeyBinding(action: .copyFile,         keyCode: 0x60, modifiers: .none),         // F5
        HotKeyBinding(action: .moveFile,         keyCode: 0x61, modifiers: .none),         // F6
        HotKeyBinding(action: .newFolder,        keyCode: 0x62, modifiers: .none),         // F7
        HotKeyBinding(action: .deleteFile,       keyCode: 0x64, modifiers: .none),         // F8
        HotKeyBinding(action: .renameFile,       keyCode: 0x78, modifiers: .none),         // F2
        HotKeyBinding(action: .packFiles,        keyCode: 0x60, modifiers: .option),       // ⌥F5
        HotKeyBinding(action: .unpackFiles,      keyCode: 0x65, modifiers: .option),       // ⌥F9
        HotKeyBinding(action: .compareContent,   keyCode: 0x08, modifiers: .control),      // ⌃C
        HotKeyBinding(action: .syncDirectories,  keyCode: 0x01, modifiers: .control),      // ⌃S

        // ── Navigation ──
        HotKeyBinding(action: .togglePanelFocus, keyCode: 0x30, modifiers: .none),         // Tab
        HotKeyBinding(action: .moveUp,           keyCode: 0x7E, modifiers: .none),         // ↑
        HotKeyBinding(action: .moveDown,         keyCode: 0x7D, modifiers: .none),         // ↓
        HotKeyBinding(action: .pageUp,           keyCode: 0x74, modifiers: .none),         // PageUp
        HotKeyBinding(action: .pageDown,         keyCode: 0x79, modifiers: .none),         // PageDown
        HotKeyBinding(action: .moveToTop,        keyCode: 0x73, modifiers: .none),         // Home
        HotKeyBinding(action: .moveToBottom,     keyCode: 0x77, modifiers: .none),         // End
        HotKeyBinding(action: .openSelected,     keyCode: 0x24, modifiers: .none),         // Return
        HotKeyBinding(action: .parentDirectory,  keyCode: 0x33, modifiers: .none),         // Backspace
        HotKeyBinding(action: .refreshPanels,    keyCode: 0x0F, modifiers: .command),      // ⌘R

        // ── Selection (TC style: Insert, Num+/-/*) ──
        HotKeyBinding(action: .toggleMark,       keyCode: 0x72, modifiers: .none),         // Insert
        HotKeyBinding(action: .markByPattern,    keyCode: 0x45, modifiers: .none),         // Num+
        HotKeyBinding(action: .unmarkByPattern,  keyCode: 0x4E, modifiers: .none),         // Num−
        HotKeyBinding(action: .invertMarks,      keyCode: 0x43, modifiers: .none),         // Num×
        HotKeyBinding(action: .markAll,          keyCode: 0x00, modifiers: .command),      // ⌘A
        HotKeyBinding(action: .unmarkAll,        keyCode: 0x35, modifiers: .none),         // Escape
        HotKeyBinding(action: .markSameExtension, keyCode: 0x00, modifiers: [.command, .shift]), // ⌘⇧A
        HotKeyBinding(action: .clearSelection,   keyCode: 0x35, modifiers: .command),      // ⌘Esc

        // ── Clipboard (macOS + Ctrl fallback) ──
        HotKeyBinding(action: .clipboardCopy,    keyCode: 0x08, modifiers: .command),      // ⌘C
        HotKeyBinding(action: .clipboardCut,     keyCode: 0x07, modifiers: .command),      // ⌘X
        HotKeyBinding(action: .clipboardPaste,   keyCode: 0x09, modifiers: .command),      // ⌘V

        // ── Tabs ──
        HotKeyBinding(action: .newTab,           keyCode: 0x11, modifiers: .command),      // ⌘T
        HotKeyBinding(action: .closeTab,         keyCode: 0x0D, modifiers: .command),      // ⌘W
        HotKeyBinding(action: .nextTab,          keyCode: 0x1E, modifiers: [.command, .shift]), // ⌘⇧]
        HotKeyBinding(action: .prevTab,          keyCode: 0x21, modifiers: [.command, .shift]), // ⌘⇧[

        // ── Search ──
        HotKeyBinding(action: .findFiles,        keyCode: 0x62, modifiers: .option),       // ⌥F7
        
        // ── Network ──
        HotKeyBinding(action: .connectToServer,    keyCode: 0x2D, modifiers: .control),    // ⌃N
        HotKeyBinding(action: .networkNeighborhood, keyCode: 0x00, modifiers: .none),      // No default
        
        // ── Application ──
        HotKeyBinding(action: .toggleHiddenFiles, keyCode: 0x2F, modifiers: .command),     // ⌘.
        HotKeyBinding(action: .openSettings,     keyCode: 0x2B, modifiers: .command),      // ⌘,
        HotKeyBinding(action: .exitApp,          keyCode: 0x0C, modifiers: .command),      // ⌘Q
    ]

    // ═══════════════════════════════════════════════════════════════════
    // MARK: - Finder Layout (macOS native shortcuts)
    // ═══════════════════════════════════════════════════════════════════
    static let finder: [HotKeyBinding] = [
        // ── File Operations (Finder style) ──
        HotKeyBinding(action: .viewFile,         keyCode: 0x31, modifiers: .none),         // Space (Quick Look)
        HotKeyBinding(action: .editFile,         keyCode: 0x24, modifiers: .command),      // ⌘Return
        HotKeyBinding(action: .copyFile,         keyCode: 0x08, modifiers: .command),      // ⌘C (then paste = copy)
        HotKeyBinding(action: .moveFile,         keyCode: 0x07, modifiers: .command),      // ⌘X (then paste = move)
        HotKeyBinding(action: .newFolder,        keyCode: 0x2D, modifiers: [.command, .shift]), // ⌘⇧N
        HotKeyBinding(action: .deleteFile,       keyCode: 0x33, modifiers: .command),      // ⌘Backspace
        HotKeyBinding(action: .renameFile,       keyCode: 0x78, modifiers: .none),         // F2
        HotKeyBinding(action: .packFiles,        keyCode: 0x00, modifiers: .none),         // Not standard
        HotKeyBinding(action: .unpackFiles,      keyCode: 0x00, modifiers: .none),         // Not standard
        HotKeyBinding(action: .compareContent,   keyCode: 0x00, modifiers: .none),         // Not standard
        HotKeyBinding(action: .syncDirectories,  keyCode: 0x00, modifiers: .none),         // Not standard

        // ── Navigation ──
        HotKeyBinding(action: .togglePanelFocus, keyCode: 0x30, modifiers: .none),         // Tab
        HotKeyBinding(action: .moveUp,           keyCode: 0x7E, modifiers: .none),         // ↑
        HotKeyBinding(action: .moveDown,         keyCode: 0x7D, modifiers: .none),         // ↓
        HotKeyBinding(action: .pageUp,           keyCode: 0x74, modifiers: .none),         // PageUp
        HotKeyBinding(action: .pageDown,         keyCode: 0x79, modifiers: .none),         // PageDown
        HotKeyBinding(action: .moveToTop,        keyCode: 0x7E, modifiers: [.command, .option]), // ⌘⌥↑
        HotKeyBinding(action: .moveToBottom,     keyCode: 0x7D, modifiers: [.command, .option]), // ⌘⌥↓
        HotKeyBinding(action: .openSelected,     keyCode: 0x24, modifiers: .none),         // Return (rename in Finder, but open here)
        HotKeyBinding(action: .parentDirectory,  keyCode: 0x7E, modifiers: .command),      // ⌘↑
        HotKeyBinding(action: .refreshPanels,    keyCode: 0x0F, modifiers: .command),      // ⌘R

        // ── Selection (macOS style) ──
        HotKeyBinding(action: .toggleMark,       keyCode: 0x31, modifiers: .none),         // Space
        HotKeyBinding(action: .markByPattern,    keyCode: 0x00, modifiers: .none),         // Not standard
        HotKeyBinding(action: .unmarkByPattern,  keyCode: 0x00, modifiers: .none),         // Not standard
        HotKeyBinding(action: .invertMarks,      keyCode: 0x00, modifiers: .none),         // Not standard
        HotKeyBinding(action: .markAll,          keyCode: 0x00, modifiers: .command),      // ⌘A
        HotKeyBinding(action: .unmarkAll,        keyCode: 0x35, modifiers: .none),         // Escape
        HotKeyBinding(action: .markSameExtension, keyCode: 0x00, modifiers: .none),        // Not standard
        HotKeyBinding(action: .clearSelection,   keyCode: 0x35, modifiers: .none),         // Escape

        // ── Clipboard ──
        HotKeyBinding(action: .clipboardCopy,    keyCode: 0x08, modifiers: .command),      // ⌘C
        HotKeyBinding(action: .clipboardCut,     keyCode: 0x07, modifiers: .command),      // ⌘X
        HotKeyBinding(action: .clipboardPaste,   keyCode: 0x09, modifiers: .command),      // ⌘V

        // ── Tabs ──
        HotKeyBinding(action: .newTab,           keyCode: 0x11, modifiers: .command),      // ⌘T
        HotKeyBinding(action: .closeTab,         keyCode: 0x0D, modifiers: .command),      // ⌘W
        HotKeyBinding(action: .nextTab,          keyCode: 0x1E, modifiers: [.control, .shift]), // ⌃⇧Tab or ⌃]
        HotKeyBinding(action: .prevTab,          keyCode: 0x21, modifiers: .control),      // ⌃[

        // ── Search ──
        HotKeyBinding(action: .findFiles,        keyCode: 0x03, modifiers: .command),      // ⌘F
        
        // ── Network ──
        HotKeyBinding(action: .connectToServer,    keyCode: 0x0E, modifiers: .command),    // ⌘K (Finder style)
        HotKeyBinding(action: .networkNeighborhood, keyCode: 0x00, modifiers: .none),      // No default
        
        // ── Application ──
        HotKeyBinding(action: .toggleHiddenFiles, keyCode: 0x2F, modifiers: [.command, .shift]), // ⌘⇧.
        HotKeyBinding(action: .openSettings,     keyCode: 0x2B, modifiers: .command),      // ⌘,
        HotKeyBinding(action: .exitApp,          keyCode: 0x0C, modifiers: .command),      // ⌘Q
    ]
    
    // MARK: - Get bindings for preset
    static func bindings(for preset: HotKeyPreset) -> [HotKeyBinding] {
        switch preset {
        case .totalCommander: return totalCommander
        case .finder: return finder
        case .custom: return [] // No preset, keep current
        }
    }
}
