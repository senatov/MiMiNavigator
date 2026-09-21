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

    // MARK: - OptionSet requirement
    init(rawValue: UInt) {
        self.rawValue = rawValue
    }

    static let command  = HotKeyModifiers(rawValue: 1 << 0)
    static let option   = HotKeyModifiers(rawValue: 1 << 1)
    static let control  = HotKeyModifiers(rawValue: 1 << 2)
    static let shift    = HotKeyModifiers(rawValue: 1 << 3)
    static let function = HotKeyModifiers(rawValue: 1 << 4)

    static let none: HotKeyModifiers = []

    // MARK: - Conversion from NSEvent.ModifierFlags
    static func fromNSFlags(_ nsFlags: NSEvent.ModifierFlags) -> HotKeyModifiers {
        var result: HotKeyModifiers = []
        if nsFlags.contains(.command)  { result.insert(.command) }
        if nsFlags.contains(.option)   { result.insert(.option) }
        if nsFlags.contains(.control)  { result.insert(.control) }
        if nsFlags.contains(.shift)    { result.insert(.shift) }
        if nsFlags.contains(.function) { result.insert(.function) }
        return result
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
        if keyCode == 0 && modifiers.isEmpty { return "" }
        let modStr = modifiers.subtracting(.function).displayString
        let keyStr = HotKeyBinding.keyName(for: keyCode)
        return modStr.isEmpty ? keyStr : "\(modStr)\(keyStr)"
    }

    // MARK: - Key Name Mapping
    private static let keyNames: [UInt16: String] = [
        0x7A: "F1", 0x78: "F2", 0x63: "F3", 0x76: "F4", 0x60: "F5",
        0x61: "F6", 0x62: "F7", 0x64: "F8", 0x65: "F9", 0x6D: "F10",
        0x67: "F11", 0x6F: "F12", 0x69: "F13", 0x6B: "F14", 0x71: "F15",
        0x6A: "F16", 0x40: "F17", 0x4F: "F18", 0x50: "F19",
        0x7E: "↑", 0x7D: "↓", 0x7B: "←", 0x7C: "→",
        0x24: "↩", 0x4C: "⌅", 0x33: "⌫", 0x75: "⌦",
        0x73: "Home", 0x77: "End", 0x74: "PageUp", 0x79: "PageDown",
        0x35: "⎋", 0x30: "⇥", 0x31: "Space", 0x72: "Insert",
        0x45: "Num+", 0x4E: "Num−", 0x43: "Num×", 0x4B: "Num÷",
        0x00: "A", 0x0B: "B", 0x08: "C", 0x02: "D", 0x0E: "E",
        0x03: "F", 0x05: "G", 0x04: "H", 0x22: "I", 0x26: "J",
        0x28: "K", 0x25: "L", 0x2E: "M", 0x2D: "N", 0x1F: "O",
        0x23: "P", 0x0C: "Q", 0x0F: "R", 0x01: "S", 0x11: "T",
        0x20: "U", 0x09: "V", 0x0D: "W", 0x07: "X", 0x10: "Y", 0x06: "Z",
        0x2F: ".", 0x2B: ",", 0x2C: "/", 0x1B: "-", 0x18: "=",
        0x21: "[", 0x1E: "]", 0x29: ";", 0x27: "'", 0x32: "`", 0x2A: "\\",
    ]
    private static let keyCodesByName: [String: UInt16] = {
        var result = Dictionary(uniqueKeysWithValues: keyNames.map { ($0.value, $0.key) })
        result["Escape"] = 0x35
        result["Tab"] = 0x30
        return result
    }()
    static func keyName(for keyCode: UInt16) -> String {
        keyNames[keyCode] ?? "0x\(String(keyCode, radix: 16, uppercase: true))"
    }

    /// Reverse lookup: key name → keyCode (for UI input)
    static func keyCode(forName name: String) -> UInt16? {
        keyCodesByName[name]
    }
}
