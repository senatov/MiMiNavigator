// HotKeySettingsCoordinator.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 10.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Manages the Keyboard Shortcuts settings window as a standalone NSWindow

import Foundation

// MARK: - Hot Key Settings Coordinator
/// Opens the Settings panel on the Hotkeys tab.
/// Delegates to SettingsCoordinator — no separate window.
@MainActor
final class HotKeySettingsCoordinator {

    static let shared = HotKeySettingsCoordinator()

    private init() {}

    // MARK: - Show Settings (Hotkeys tab)

    func showSettings() {
        SettingsCoordinator.shared.openOnSection(.hotkeys)
    }

    func closeSettings() {
        SettingsCoordinator.shared.close()
    }
}
