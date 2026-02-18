// HotKeyStore.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 10.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Persistent storage for user-customized keyboard shortcuts — JSON in UserDefaults

import AppKit
import Foundation

// MARK: - Hot Key Store
/// Central store for all keyboard shortcut bindings.
/// Loads from UserDefaults on init, falls back to HotKeyDefaults.
/// Provides fast lookup by keyCode+modifiers → action.
@MainActor
@Observable
final class HotKeyStore {

    static let shared = HotKeyStore()

    // MARK: - Storage
    /// All current bindings, indexed by action
    private(set) var bindings: [HotKeyAction: HotKeyBinding] = [:]

    /// Reverse lookup: (keyCode, modifiers.rawValue) → action
    private var reverseLookup: [UInt64: HotKeyAction] = [:]

    private let userDefaultsKey = "com.senatov.MiMiNavigator.hotkeys"

    // MARK: - Init
    private init() {
        loadBindings()
    }

    // MARK: - Public API

    /// Get binding for a specific action
    func binding(for action: HotKeyAction) -> HotKeyBinding {
        bindings[action] ?? HotKeyDefaults.bindingsByAction[action]
            ?? HotKeyBinding(action: action, keyCode: 0, modifiers: .none)
    }

    /// Get all bindings as sorted array (for UI display)
    var allBindings: [HotKeyBinding] {
        HotKeyAction.allCases.map { binding(for: $0) }
    }

    /// Get bindings for a specific category
    func bindings(for category: HotKeyCategory) -> [HotKeyBinding] {
        HotKeyAction.allCases
            .filter { $0.category == category }
            .map { binding(for: $0) }
    }

    /// Lookup action by keyCode + modifiers (used by keyboard handler)
    func action(forKeyCode keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> HotKeyAction? {
        // Build a normalized key for lookup
        let normalizedMods = HotKeyModifiers.fromNSFlags(modifiers)
        let key = lookupKey(keyCode: keyCode, modifiers: normalizedMods)
        return reverseLookup[key]
    }

    /// Update a binding for an action
    func updateBinding(action: HotKeyAction, keyCode: UInt16, modifiers: HotKeyModifiers) {
        let newBinding = HotKeyBinding(action: action, keyCode: keyCode, modifiers: modifiers)

        // Remove old reverse entry if it exists
        if let old = bindings[action] {
            let oldKey = lookupKey(keyCode: old.keyCode, modifiers: old.modifiers)
            reverseLookup.removeValue(forKey: oldKey)
        }

        // Set new binding
        bindings[action] = newBinding

        // Add new reverse entry
        let newKey = lookupKey(keyCode: keyCode, modifiers: modifiers)
        reverseLookup[newKey] = action

        saveBindings()
        log.info("[HotKeys] Updated: \(action.rawValue) → \(newBinding.displayString)")
    }

    /// Check if a key combo is already used by another action
    func conflictingAction(keyCode: UInt16, modifiers: HotKeyModifiers, excluding: HotKeyAction? = nil) -> HotKeyAction? {
        let key = lookupKey(keyCode: keyCode, modifiers: modifiers)
        if let found = reverseLookup[key], found != excluding {
            return found
        }
        return nil
    }

    /// Reset all bindings to factory defaults
    func resetToDefaults() {
        log.info("[HotKeys] Resetting to defaults")
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        loadDefaults()
        saveBindings()
    }

    /// Reset a single binding to its default
    func resetBinding(for action: HotKeyAction) {
        if let defaultBinding = HotKeyDefaults.bindingsByAction[action] {
            updateBinding(action: action, keyCode: defaultBinding.keyCode, modifiers: defaultBinding.modifiers)
        }
    }

    // MARK: - Persistence

    private func loadBindings() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let stored = try? JSONDecoder().decode([HotKeyBinding].self, from: data) {
            log.info("[HotKeys] Loaded \(stored.count) custom bindings from UserDefaults")
            applyBindings(stored)
        } else {
            log.info("[HotKeys] No custom bindings found, using defaults")
            loadDefaults()
        }
    }

    private func loadDefaults() {
        applyBindings(HotKeyDefaults.bindings)
    }

    private func applyBindings(_ list: [HotKeyBinding]) {
        bindings.removeAll()
        reverseLookup.removeAll()

        for binding in list {
            bindings[binding.action] = binding
            let key = lookupKey(keyCode: binding.keyCode, modifiers: binding.modifiers)
            reverseLookup[key] = binding.action
        }

        // Fill any missing actions with defaults
        for action in HotKeyAction.allCases where bindings[action] == nil {
            if let defaultBinding = HotKeyDefaults.bindingsByAction[action] {
                bindings[action] = defaultBinding
                let key = lookupKey(keyCode: defaultBinding.keyCode, modifiers: defaultBinding.modifiers)
                reverseLookup[key] = action
            }
        }

        // Register keyCode aliases (extra keys that trigger the same action
        // without changing the primary binding shown in Settings)
        for alias in HotKeyDefaults.aliases {
            let key = lookupKey(keyCode: alias.keyCode, modifiers: alias.modifiers)
            reverseLookup[key] = alias.action
        }
    }

    private func saveBindings() {
        let list = Array(bindings.values)
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
            log.debug("[HotKeys] Saved \(list.count) bindings")
        } else {
            log.error("[HotKeys] Failed to encode bindings")
        }
    }

    // MARK: - Helpers

    /// Composite key for reverse lookup dictionary
    private func lookupKey(keyCode: UInt16, modifiers: HotKeyModifiers) -> UInt64 {
        // Strip .function for F-key matching consistency
        let cleanMods = modifiers.subtracting(.function)
        return UInt64(keyCode) | (UInt64(cleanMods.rawValue) << 16)
    }
}
