// HIGLegacyButtons.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 22.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Legacy button type aliases — kept for backward compatibility.

import SwiftUI

// MARK: - Legacy Button Aliases
typealias HIGPrimaryButton = _LegacyHIGPrimaryButton
typealias HIGSecondaryButton = _LegacyHIGSecondaryButton

// MARK: - _LegacyHIGPrimaryButton
struct _LegacyHIGPrimaryButton: View {
    let title: String
    let action: () -> Void
    var isDestructive: Bool = false
    var body: some View {
        Button(title, action: action)
            .buttonStyle(ThemedButtonStyle())
            .tint(isDestructive ? .red : .accentColor)
            .controlSize(.large)
    }
}

// MARK: - _LegacyHIGSecondaryButton
struct _LegacyHIGSecondaryButton: View {
    let title: String
    let action: () -> Void
    var body: some View {
        Button(title, action: action)
            .buttonStyle(ThemedButtonStyle())
            .controlSize(.large)
    }
}
