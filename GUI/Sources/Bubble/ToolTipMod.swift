// ToolTipMod.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 31.10.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//  Description: Custom tooltip bubble for non-toolbar elements (e.g. panel divider).
//               For toolbar buttons use native .help() instead.

import SwiftUI

// MARK: - Shows a lightweight tooltip bubble at an arbitrary position without intercepting hit tests.
struct ToolTipMod: ViewModifier {
    @Binding var isVisible: Bool
    let text: String
    let position: CGPoint

    func body(content: Content) -> some View {
        ZStack(alignment: .topLeading) {
            content
            if isVisible {
                TooltipBubble(text: text, position: position)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
        }
        .animation(.easeInOut(duration: 0.12), value: isVisible)
    }

    // MARK: -
    private struct TooltipBubble: View {
        let text: String
        let position: CGPoint

        var body: some View {
            Text(text)
                .font(.footnote)
                .padding(6)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(.white.opacity(0.15), lineWidth: 1)
                )
                .shadow(radius: 6, y: 2)
                .position(x: position.x, y: position.y)
                .allowsHitTesting(false)
        }
    }
}
