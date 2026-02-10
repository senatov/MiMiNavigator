// HotKeyBinding.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 10.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Single keyboard shortcut binding — keyCode + modifiers, Codable/JSON-friendly

import AppKit
import Foundation

// MARK: - Modifier Flags (Codable-friendly wrapper)
/// Bitmask wrapper for NSEvent.ModifierFlags that supports Codable
struct HotKeyModifiers: OptionSet, Codable, Hashable, Sendable {
    let rawValue: UInt

    static let command  = HotKeyModifiers(rawValue: 1 << 0)
    static let option   = HotKeyModifiers(rawValue: 1 << 1)
    static let control  = HotKeyModifiers(rawValue: 1 << 2)
    static let shift    = HotKeyModifiers(rawValue: 1 << 3)
    static let function = HotKeyModifiers(rawValue: 1 << 4)

    static let none: HotKeyModifiers = []

    // MARK: - Conversion from NSEvent.ModifierFlags
    init(from nsFlags: NSEvent.ModifierFlags) {
        var result: HotKeyModifiers = []
        if nsFlags.contains(.command)  { result.insert(.command) }
        if nsFlags.contains(.option)   { result.insert(.option) }
        if nsFlags.contains(.control)  { result.insert(.control) }
        if nsFlags.contains(.shift)    { result.insert(.shift) }
        if nsFlags.contains(.function) { result.insert(.function) }
        self = result
    }

    // MARK: - Conversion to NSEvent.ModifierFlags
    var nsModifierFlags: NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if contains(.command)  { flags.insert(.command) }
        if contains(.option)   { flags.insert(.option) }
        if contains(.control)  { flags.insert(.control) }
        if contains(.shift)    { flags.insert(.shift) }
        if contains(.function) { flags.insert(.function) }
        return flags
    }

    // MARK: - Display String
    /// Human-readable modifier symbols: ⌃⌥⇧⌘
    var displayString: String {
        var parts: [String] = []
        if contains(.control) { parts.append("⌃") }
        if contains(.option)  { parts.append("⌥") }
        if contains(.shift)   { parts.append("⇧") }
        if contains(.command) { parts.append("⌘") }
        if contains(.function) { parts.append("fn") }
        return parts.joined()
    }

    /// Matches NSEvent modifier flags (ignoring .function and .numericPad for F-keys)
    func matches(eventModifiers: NSEvent.ModifierFlags) -> Bool {
        let relevant = eventModifiers.intersection(.deviceIndependentFlagsMask)
            .subtracting([.function, .numericPad])
        let selfNS = nsModifierFlags.subtracting([.function, .numericPad])
        return relevant == selfNS
    }
}

// MARK: - Hot Key Binding
/// A single shortcut binding: action → keyCode + modifiers
struct HotKeyBinding: Codable, Identifiable, Hashable, Sendable {
    let action: HotKeyAction
    var keyCode: UInt16
    var modifiers: HotKeyModifiers

    var id: String { action.rawValue }

    // MARK: - Display String
    /// Human-readable shortcut: "⌥F7", "⌘⇧F", "F3", "Space"
    var displayString: String {
        let modStr = modifiers.displayString
        let keyStr = HotKeyBinding.keyName(for: keyCode)
        return modStr.isEmpty ? keyStr : "\(modStr)\(keyStr)"
    }

    // MARK: - Key Name Mapping
    static func keyName(for keyCode: UInt16) -> String {
        switch keyCode {
        // Function keys
        case 0x7A: return "F1"
        case 0x78: return "F2"
        case 0x63: return "F3"
        case 0x76: return "F4"
        case 0x60: return "F5"
        case 0x61: return "F6"
        case 0x62: return "F7"
        case 0x64: return "F8"
        case 0x65: return "F9"
        case 0x6D: return "F10"
        case 0x67: return "F11"
        case 0x6F: return "F12"
        // Navigation
        case 0x7E: return "↑"
        case 0x7D: return "↓"
        case 0x7B: return "←"
        case 0x7C: return "→"
        case 0x24: return "↩"  // Return
        case 0x4C: return "⌅"  // Enter (numpad)
        case 0x33: return "⌫"  // Delete
        case 0x75: return "⌦"  // Forward Delete
        case 0x73: return "Home"
        case 0x77: return "End"
        case 0x74: return "PageUp"
        case 0x79: return "PageDown"
        case 0x35: return "⎋"  // Escape
        case 0x30: return "⇥"  // Tab
        case 0x31: return "Space"
        case 0x72: return "Insert"
        // Numpad
        case 0x45: return "Num+"
        case 0x4E: return "Num−"
        case 0x43: return "Num×"
        case 0x4B: return "Num÷"
        // Letters (selected common ones)
        case 0x00: return "A"
        case 0x0B: return "B"
        case 0x08: return "C"
        case 0x02: return "D"
        case 0x0E: return "E"
        case 0x03: return "F"
        case 0x05: return "G"
        case 0x04: return "H"
        case 0x22: return "I"
        case 0x26: return "J"
        case 0x28: return "K"
        case 0x25: return "L"
        case 0x2E: return "M"
        case 0x2D: return "N"
        case 0x1F: return "O"
        case 0x23: return "P"
        case 0x0C: return "Q"
        case 0x0F: return "R"
        case 0x01: return "S"
        case 0x11: return "T"
        case 0x20: return "U"
        case 0x09: return "V"
        case 0x0D: return "W"
        case 0x07: return "X"
        case 0x10: return "Y"
        case 0x06: return "Z"
        // Punctuation
        case 0x2F: return "."
        case 0x2B: return ","
        case 0x2C: return "/"
        case 0x1B: return "-"
        case 0x18: return "="
        case 0x21: return "["
        case 0x1E: return "]"
        case 0x29: return ";"
        case 0x27: return "'"
        case 0x32: return "`"
        case 0x2A: return "\\"
        default:   return "0x\(String(keyCode, radix: 16, uppercase: true))"
        }
    }

    /// Reverse lookup: key name → keyCode (for UI input)
    static func keyCode(forName name: String) -> UInt16? {
        let map: [String: UInt16] = [
            "F1": 0x7A, "F2": 0x78, "F3": 0x63, "F4": 0x76, "F5": 0x60,
            "F6": 0x61, "F7": 0x62, "F8": 0x64, "F9": 0x65, "F10": 0x6D,
            "F11": 0x67, "F12": 0x6F,
            "↑": 0x7E, "↓": 0x7D, "←": 0x7B, "→": 0x7C,
            "↩": 0x24, "⌅": 0x4C, "⌫": 0x33, "⌦": 0x75,
            "Home": 0x73, "End": 0x77, "PageUp": 0x74, "PageDown": 0x79,
            "⎋": 0x35, "Escape": 0x35, "⇥": 0x30, "Tab": 0x30,
            "Space": 0x31, "Insert": 0x72,
            "Num+": 0x45, "Num−": 0x4E, "Num×": 0x43, "Num÷": 0x4B,
            "A": 0x00, "B": 0x0B, "C": 0x08, "D": 0x02, "E": 0x0E,
            "F": 0x03, "G": 0x05, "H": 0x04, "I": 0x22, "J": 0x26,
            "K": 0x28, "L": 0x25, "M": 0x2E, "N": 0x2D, "O": 0x1F,
            "P": 0x23, "Q": 0x0C, "R": 0x0F, "S": 0x01, "T": 0x11,
            "U": 0x20, "V": 0x09, "W": 0x0D, "X": 0x07, "Y": 0x10, "Z": 0x06,
        ]
        return map[name]
    }
}
