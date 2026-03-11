// SettingsHotkeysPane.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 24.02.2026.
// Copyright © 2026 Senatov. All rights reserved.

import SwiftUI

// MARK: - ════════════════════════════════════════════
// MARK:   Hotkeys  — uses existing HotKeySettingsView
// MARK: - ════════════════════════════════════════════

struct SettingsHotkeysPane: View {
    var body: some View {
        HotKeySettingsView(embedded: true)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// NOTE: SettingsColorsPane → SettingsColorsPane.swift
// NOTE: SettingsPermissionsPane → SettingsPermissionsPane.swift
