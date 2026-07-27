// SettingsPanes.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 24.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Shared helpers for settings panes

import SwiftUI

// MARK: - Shared style helpers

enum SettingsVisualStyle {
    static let accent = Color.accentColor
    static let cardTint = Color.primary.opacity(0.025)
    static let insetFill = Color.primary.opacity(0.035)
    static let hairline = Color.primary.opacity(0.10)
    static let sidebarFill = Color.primary.opacity(0.025)
    static let cornerRadius: CGFloat = 16
}

// MARK: - Settings Row

struct SettingsRow<Content: View>: View {
    let label: String
    let help: String
    let labelWidth: CGFloat
    let content: Content

    init(
        label: String,
        help: String,
        labelWidth: CGFloat = 200,
        @ViewBuilder content: () -> Content
    ) {
        self.label = label
        self.help = help
        self.labelWidth = labelWidth
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(width: labelWidth, alignment: .trailing)
                .help(help)
            Spacer().frame(width: 16)
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 5)
    }
}

struct SettingsGroupBox<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(16)
        .background(
            SettingsVisualStyle.insetFill,
            in: RoundedRectangle(cornerRadius: SettingsVisualStyle.cornerRadius, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: SettingsVisualStyle.cornerRadius, style: .continuous)
                .stroke(SettingsVisualStyle.hairline, lineWidth: 0.5)
        }
    }
}

// MARK: - Settings Fluent Group Box Style

struct SettingsFluentGroupBoxStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            configuration.label
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
            configuration.content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            SettingsVisualStyle.insetFill,
            in: RoundedRectangle(cornerRadius: SettingsVisualStyle.cornerRadius, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: SettingsVisualStyle.cornerRadius, style: .continuous)
                .stroke(SettingsVisualStyle.hairline, lineWidth: 0.5)
        }
    }
}
