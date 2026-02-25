// ShortcutConflictValidator.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 25.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Validates keyboard shortcuts against macOS system reserved combos
//   and internal app bindings. Shows conflict popup with safe alternatives.

import AppKit
import Foundation

// MARK: - Conflict Kind
enum ShortcutConflictKind: Sendable {
    case systemReserved(description: String)
    case appInternal(existingAction: HotKeyAction)
}

// MARK: - Conflict Result
struct ShortcutConflictResult: Sendable {
    let conflict: ShortcutConflictKind?
    let suggested: [(keyCode: UInt16, modifiers: HotKeyModifiers, display: String)]

    var hasConflict: Bool { conflict != nil }

    var conflictDescription: String {
        switch conflict {
        case .systemReserved(let desc):
            return "⚠️ '\(desc)' — reserved by macOS"
        case .appInternal(let action):
            return "⚠️ Already assigned to '\(action.displayName)'"
        case .none:
            return ""
        }
    }
}

// MARK: - Shortcut Key Helper (nonisolated — safe for static let closures)
private func makeShortcutKey(keyCode: UInt16, modifiers: HotKeyModifiers) -> UInt64 {
    let cleanMods = modifiers.subtracting(.function)
    return UInt64(keyCode) | (UInt64(cleanMods.rawValue) << 16)
}

// MARK: - Shortcut Conflict Validator
@MainActor
enum ShortcutConflictValidator {

    // MARK: - Public API

    static func validate(
        keyCode: UInt16,
        modifiers: HotKeyModifiers,
        forAction action: HotKeyAction
    ) -> ShortcutConflictResult {
        // 1. Check system reserved shortcuts
        if let sysDesc = systemConflict(keyCode: keyCode, modifiers: modifiers) {
            let suggestions = suggestAlternatives(keyCode: keyCode, modifiers: modifiers, forAction: action)
            return ShortcutConflictResult(
                conflict: .systemReserved(description: sysDesc),
                suggested: suggestions
            )
        }

        // 2. Check internal app conflicts
        if let existing = HotKeyStore.shared.conflictingAction(
            keyCode: keyCode, modifiers: modifiers, excluding: action
        ) {
            let suggestions = suggestAlternatives(keyCode: keyCode, modifiers: modifiers, forAction: action)
            return ShortcutConflictResult(
                conflict: .appInternal(existingAction: existing),
                suggested: suggestions
            )
        }

        return ShortcutConflictResult(conflict: nil, suggested: [])
    }

    // MARK: - System Reserved Shortcuts

    private static func systemConflict(keyCode: UInt16, modifiers: HotKeyModifiers) -> String? {
        let key = makeShortcutKey(keyCode: keyCode, modifiers: modifiers)
        return systemReservedShortcuts[key]
    }

    /// Known macOS system shortcuts that apps should not override.
    /// Built once via nonisolated helper — no MainActor issue.
    private static let systemReservedShortcuts: [UInt64: String] = {
        var map: [UInt64: String] = [:]

        func add(_ kc: UInt16, _ mods: HotKeyModifiers, _ desc: String) {
            map[makeShortcutKey(keyCode: kc, modifiers: mods)] = desc
        }

        let cmd: HotKeyModifiers = .command
        let cmdShift: HotKeyModifiers = [.command, .shift]
        let cmdOpt: HotKeyModifiers = [.command, .option]
        let ctrlCmd: HotKeyModifiers = [.control, .command]

        // ── App lifecycle ──
        add(0x0C, cmd, "⌘Q — Quit Application")
        add(0x04, cmd, "⌘H — Hide Application")
        add(0x04, cmdOpt, "⌘⌥H — Hide Others")
        add(0x2E, cmd, "⌘M — Minimize Window")
        add(0x0D, cmd, "⌘W — Close Window")
        add(0x1F, cmd, "⌘O — Open (system)")

        // ── Edit ──
        add(0x06, cmd, "⌘Z — Undo")
        add(0x06, cmdShift, "⌘⇧Z — Redo")
        add(0x07, cmd, "⌘X — Cut")
        add(0x08, cmd, "⌘C — Copy")
        add(0x09, cmd, "⌘V — Paste")
        add(0x00, cmd, "⌘A — Select All")

        // ── Window management ──
        add(0x32, cmd, "⌘` — Cycle Windows")
        add(0x30, ctrlCmd, "⌃⌘F — Toggle Fullscreen")

        // ── Screenshot ──
        add(0x1C, cmdShift, "⌘⇧3 — Screenshot Full")
        add(0x13, cmdShift, "⌘⇧4 — Screenshot Region")
        add(0x17, cmdShift, "⌘⇧5 — Screenshot / Record")

        // ── Spotlight ──
        add(0x31, cmd, "⌘Space — Spotlight")

        // ── Force Quit ──
        add(0x35, cmdOpt, "⌘⌥Esc — Force Quit")

        // ── Accessibility ──
        add(0x60, cmd, "⌘F5 — VoiceOver Toggle")

        // ── Preferences ──
        add(0x2B, cmd, "⌘, — Preferences / Settings")

        return map
    }()

    // MARK: - Alternative Suggestions

    private static func suggestAlternatives(
        keyCode: UInt16,
        modifiers: HotKeyModifiers,
        forAction action: HotKeyAction
    ) -> [(keyCode: UInt16, modifiers: HotKeyModifiers, display: String)] {
        var results: [(keyCode: UInt16, modifiers: HotKeyModifiers, display: String)] = []

        let candidates: [HotKeyModifiers] = [
            [.command, .shift],
            [.command, .option],
            [.control, .shift],
            [.command, .shift, .option],
            [.control, .command],
            .option,
            [.option, .shift],
        ]

        for mods in candidates where mods != modifiers {
            if !hasConflictQuiet(keyCode: keyCode, modifiers: mods, forAction: action) {
                let display = HotKeyBinding(action: action, keyCode: keyCode, modifiers: mods).displayString
                results.append((keyCode, mods, display))
                if results.count >= 3 { break }
            }
        }

        // Try nearby F-keys if still < 3
        if results.count < 3 {
            let fKeys: [UInt16] = [0x7A, 0x78, 0x63, 0x76, 0x60, 0x61, 0x62, 0x64, 0x65, 0x6D, 0x67, 0x6F]
            for fk in fKeys where fk != keyCode {
                if !hasConflictQuiet(keyCode: fk, modifiers: modifiers, forAction: action) {
                    let display = HotKeyBinding(action: action, keyCode: fk, modifiers: modifiers).displayString
                    results.append((fk, modifiers, display))
                    if results.count >= 3 { break }
                }
            }
        }

        return results
    }

    /// Quick conflict check without generating suggestions (avoids recursion).
    private static func hasConflictQuiet(keyCode: UInt16, modifiers: HotKeyModifiers, forAction action: HotKeyAction) -> Bool {
        let key = makeShortcutKey(keyCode: keyCode, modifiers: modifiers)
        if systemReservedShortcuts[key] != nil { return true }
        if HotKeyStore.shared.conflictingAction(keyCode: keyCode, modifiers: modifiers, excluding: action) != nil { return true }
        return false
    }
}
