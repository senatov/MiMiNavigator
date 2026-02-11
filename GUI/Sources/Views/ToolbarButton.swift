// ToolbarButton.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 11.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Standard macOS HIG toolbar button — clean, native appearance

import SwiftUI

// MARK: - Standard Toolbar Button (macOS HIG)
/// A toolbar button following macOS 26 HIG guidelines:
/// - Uses `.bordered` or `.borderless` button style depending on context
/// - SF Symbols with `.hierarchical` rendering
/// - System-standard sizing and spacing
/// - No custom animations or colors that break native look
struct ToolbarButton: View {
    let systemImage: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .symbolRenderingMode(.hierarchical)
        }
        .help(help)
    }
}

// MARK: - Toggle Toolbar Button (macOS HIG)
/// A toolbar toggle button for on/off states (e.g., show/hide hidden files).
/// Uses native SF Symbol variants for active/inactive states.
struct ToolbarToggleButton: View {
    let systemImage: String
    let activeImage: String
    let helpActive: String
    let helpInactive: String
    @Binding var isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isActive ? activeImage : systemImage)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(isActive ? .primary : .secondary)
        }
        .help(isActive ? helpActive : helpInactive)
    }
}
