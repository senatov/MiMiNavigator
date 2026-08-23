// FindFilesAdvancedTab+Helpers.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Reusable preset and row presentation helpers for the advanced search tab.

import FindFilesKit
import SwiftUI

// MARK: - Advanced Tab Helpers
extension FindFilesAdvancedTab {
    func presetButton(_ title: String, icon: String, preset: FindFilesPreset, action: @escaping () -> Void) -> some View {
        let selected = viewModel.isPresetActive(preset)
        return Button(action: action) {
            Label(title, systemImage: selected ? "checkmark.circle.fill" : icon)
        }
        .buttonStyle(ThemedButtonStyle())
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(selected ? Color.accentColor.opacity(0.08) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(selected ? Color.accentColor.opacity(0.35) : Color.clear, lineWidth: 1)
        )
    }

    func isSelectedYear(_ years: Int) -> Bool {
        viewModel.advancedSettings.useStaleItemFilter
            && viewModel.advancedSettings.staleCriterionMode == .age
            && viewModel.advancedSettings.staleAgeUnit == .years
            && viewModel.advancedSettings.staleAgeAmount == String(years)
    }

    func rowDivider() -> some View {
        Rectangle()
            .fill(DialogColors.border.opacity(0.35))
            .frame(height: 0.5)
            .padding(.leading, 32)
    }
}
