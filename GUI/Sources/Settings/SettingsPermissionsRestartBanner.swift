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
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(.orange)
                .disabled(isRestarting)
        }
        .padding(10)
        .background(Color.orange.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.orange.opacity(0.55), lineWidth: 1)
        )
    }
}
