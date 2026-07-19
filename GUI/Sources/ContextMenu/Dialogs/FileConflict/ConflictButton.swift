// ConflictButton.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 23.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Reusable button component for conflict dialog actions

import SwiftUI

// MARK: - Conflict Button
/// Standard macOS button for conflict resolution actions.
struct ConflictButton: View {
    let title: String
    var isPrimary: Bool = false
    let action: () -> Void
    
    // MARK: - Body
    var body: some View {
        Group {
            if isPrimary {
                Button(title, action: action)
                    .buttonStyle(.borderedProminent)
            } else {
                Button(title, action: action)
                    .buttonStyle(.bordered)
            }
        }
        .controlSize(.regular)
        .keyboardFocusable()
    }
}

// MARK: - Preview
#Preview("Primary Button") {
    ConflictButton(title: "Save as Copy", isPrimary: true, action: {})
        .padding()
}

#Preview("Secondary Button") {
    ConflictButton(title: "Skip", action: {})
        .padding()
}
