// AnimatedDialogButtonStyle.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 17.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Animated button style for Connect/Save/Disconnect in dialog panels.
//   Spring scale on press, color by role, subtle hover highlight.

import SwiftUI

// MARK: - Button Role
extension AnimatedDialogButtonStyle {
    enum Role {
        case confirm     // Connect  — accent color
        case neutral     // Save     — secondary
        case destructive // Disconnect — red tint
    }
}

// MARK: - AnimatedDialogButtonStyle
struct AnimatedDialogButtonStyle: ButtonStyle {

    let role: Role
    @State private var isHovering = false

    init(role: Role = .neutral) { self.role = role }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(labelColor(isPressed: configuration.isPressed))
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(bgColor(isPressed: configuration.isPressed))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(borderColor, lineWidth: 0.6)
            )
            .scaleEffect(configuration.isPressed ? 0.94 : (isHovering ? 1.02 : 1.0))
            .animation(.spring(response: 0.22, dampingFraction: 0.65), value: configuration.isPressed)
            .animation(.easeInOut(duration: 0.15), value: isHovering)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.12)) { isHovering = hovering }
            }
    }

    // MARK: - Colors
    private func bgColor(isPressed: Bool) -> Color {
        let base: Color
        switch role {
        case .confirm:     base = .accentColor
        case .destructive: base = Color(nsColor: .systemRed)
        case .neutral:     base = Color(nsColor: .controlBackgroundColor)
        }
        if isPressed   { return base.opacity(0.75) }
        if isHovering  { return base.opacity(role == .neutral ? 0.18 : 0.88) }
        return role == .neutral ? base : base.opacity(0.82)
    }

    private func labelColor(isPressed: Bool) -> Color {
        switch role {
        case .confirm, .destructive: return .white
        case .neutral: return isPressed ? .primary : (isHovering ? .primary : .secondary)
        }
    }

    private var borderColor: Color {
        switch role {
        case .confirm:     return Color.accentColor.opacity(0.4)
        case .destructive: return Color(nsColor: .systemRed).opacity(0.4)
        case .neutral:     return Color(nsColor: .separatorColor).opacity(0.6)
        }
    }
}
