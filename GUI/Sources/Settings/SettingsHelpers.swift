// SettingsPanes.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 24.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Shared helpers for settings panes

import SwiftUI

// MARK: - Shared style helpers

struct SettingsRow<Content: View>: View {
    let label: String
    let help: String
    var labelWidth: CGFloat = 200
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(width: labelWidth, alignment: .trailing)
                .help(help)
            Spacer().frame(width: 16)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 5)
    }
}

struct SettingsGroupBox<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(DialogColors.light)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(DialogColors.border.opacity(0.5), lineWidth: 0.5)
        )
    }
}

struct StubPane: View {
    let section: SettingsSection

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: section.icon)
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.tertiary)
            Text("\(section.rawValue) settings coming soon")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
}
