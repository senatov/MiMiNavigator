// ConflictButton.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 23.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Reusable button component for conflict dialog actions

import SwiftUI

// MARK: - Conflict Button
/// Styled button for conflict resolution actions with hover effect
struct ConflictButton: View {
    let title: String
    var isPrimary: Bool = false
    let action: () -> Void
    
    @State private var isHovering = false
    
    // MARK: - Body
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: isPrimary ? .medium : .regular))
                .foregroundStyle(isPrimary ? .white : .primary)
                .padding(.vertical, 5)
                .padding(.horizontal, 12)
                .background(buttonBackground)
                .overlay(buttonBorder)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
    
    // MARK: - Private Views
    private var buttonBackground: some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(backgroundFillColor)
    }
    
    private var buttonBorder: some View {
        RoundedRectangle(cornerRadius: 5)
            .stroke(isPrimary ? Color.clear : Color.gray.opacity(0.3), lineWidth: 0.5)
    }
    
    private var backgroundFillColor: Color {
        if isPrimary {
            return isHovering ? Color.accentColor.opacity(0.9) : Color.accentColor
        } else {
            return isHovering ? Color.gray.opacity(0.15) : Color.gray.opacity(0.1)
        }
    }
}

// MARK: - Preview
#Preview("Primary Button") {
    ConflictButton(title: "Keep Both", isPrimary: true, action: {})
        .padding()
}

#Preview("Secondary Button") {
    ConflictButton(title: "Skip", action: {})
        .padding()
}
