// ConflictButton.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 23.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Reusable button component for conflict dialog actions

import SwiftUI

// MARK: - Conflict Button
/// Standard application 3D button for conflict resolution actions.
struct ConflictButton: View {
    let title: String
    let systemImage: String
    let iconTint: Color
    var isPrimary: Bool = false
    let action: () -> Void
    
    // MARK: - Body
    var body: some View {
        Button(action: action) {
            Label {
                Text(title)
            } icon: {
                Image(systemName: systemImage)
                    .foregroundStyle(iconTint)
            }
        }
        .buttonStyle(ThemedButtonStyle(tint: isPrimary ? .accentColor : nil))
        .controlSize(.regular)
        .keyboardFocusable()
    }
}

// MARK: - Preview
#Preview("Primary Button") {
    ConflictButton(title: "Save as Copy", systemImage: "doc.on.doc", iconTint: .blue, isPrimary: true, action: {})
        .padding()
}

#Preview("Secondary Button") {
    ConflictButton(title: "Skip", systemImage: "arrow.right", iconTint: .orange, action: {})
        .padding()
}
