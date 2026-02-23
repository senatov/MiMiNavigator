// ToolbarButton.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 11.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Toolbar button components — macOS 26 HIG, crisp SF Symbols

import SwiftUI

// MARK: - Shared icon style
/// Renders SF Symbol at toolbar-standard size with medium weight for crispness.
private struct ToolbarIcon: View {
    let name: String
    var active: Bool = false

    var body: some View {
        Image(systemName: name)
            .symbolRenderingMode(.hierarchical)
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(active ? Color.accentColor : Color.primary)
    }
}

// MARK: - Standard Toolbar Button
struct ToolbarButton: View {
    let systemImage: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ToolbarIcon(name: systemImage)
        }
        .buttonStyle(.borderless)
        .help(help)
    }
}

// MARK: - Toggle Toolbar Button
struct ToolbarToggleButton: View {
    let systemImage: String
    let activeImage: String
    let helpActive: String
    let helpInactive: String
    @Binding var isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ToolbarIcon(name: isActive ? activeImage : systemImage, active: isActive)
        }
        .buttonStyle(.borderless)
        .help(isActive ? helpActive : helpInactive)
    }
}
