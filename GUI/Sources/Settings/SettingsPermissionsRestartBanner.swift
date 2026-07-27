// SettingsPermissionsRestartBanner.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Restart prompt shown after granting new folder permissions.

import SwiftUI

// MARK: - Settings Permissions Restart Banner
struct SettingsPermissionsRestartBanner: View {
    let isRestarting: Bool
    let onRestart: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.clockwise.circle.fill")
                .foregroundStyle(.orange)
            Text("Restart MiMiNavigator to activate the new folder permissions.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
            Spacer()
            Button("Restart Now", action: onRestart)
                .buttonStyle(.glass)
                .controlSize(.small)
                .disabled(isRestarting)
        }
        .padding(12)
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
