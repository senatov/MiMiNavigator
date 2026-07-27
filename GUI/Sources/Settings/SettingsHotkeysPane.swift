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
        HotKeySettingsView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                SettingsVisualStyle.insetFill,
                in: RoundedRectangle(cornerRadius: SettingsVisualStyle.cornerRadius, style: .continuous)
            )
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
    }
}

// NOTE: SettingsColorsPane → SettingsColorsPane.swift
// NOTE: SettingsPermissionsPane → SettingsPermissionsPane.swift
