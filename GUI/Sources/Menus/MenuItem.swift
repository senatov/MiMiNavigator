// MenuItem.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 28.05.2024.
//  Copyright © 2024 Senatov. All rights reserved.
// Description: Menu item model — supports live shortcut display from HotKeyStore

import Foundation

// MARK: - Menu item with action and optional keyboard shortcut
struct MenuItem: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let action: @MainActor @Sendable () -> Void
    /// Optional binding to HotKeyAction — when set, shortcut text is read live from HotKeyStore.
    let hotKeyAction: HotKeyAction?
    /// Static shortcut string — used only when hotKeyAction is nil (legacy/non-rebindable items).
    let staticShortcut: String?

    /// Live shortcut display string — reads from HotKeyStore if hotKeyAction is set.
    @MainActor
    var shortcut: String? {
        if let hkAction = hotKeyAction {
            let binding = HotKeyStore.shared.binding(for: hkAction)
            let display = binding.displayString
            return display.isEmpty || binding.keyCode == 0 ? nil : display
        }
        return staticShortcut
    }

    /// Primary initializer with HotKeyAction binding (live shortcut)
    init(title: String, action: @MainActor @Sendable @escaping () -> Void, hotKey: HotKeyAction) {
        self.title = title
        self.action = action
        self.hotKeyAction = hotKey
        self.staticShortcut = nil
    }

    /// Legacy initializer with static shortcut string
    init(title: String, action: @MainActor @Sendable @escaping () -> Void, shortcut: String?) {
        self.title = title
        self.action = action
        self.hotKeyAction = nil
        self.staticShortcut = shortcut
    }

    // MARK: - Equatable
    static func == (lhs: MenuItem, rhs: MenuItem) -> Bool {
        lhs.id == rhs.id
    }

    // MARK: - Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
