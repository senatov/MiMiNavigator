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
        DownToolbarGlassButtonStyle(
            isHovered: isHovering,
            tint: roleTint,
            horizontalPadding: 14,
            verticalPadding: 6
        )
        .makeBody(configuration: configuration)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.12)) { isHovering = hovering }
            }
    }

    // MARK: - Role Tint
    private var roleTint: Color? {
        switch role {
        case .confirm: return .accentColor
        case .destructive: return Color(nsColor: .systemRed)
        case .neutral: return nil
        }
    }
}
