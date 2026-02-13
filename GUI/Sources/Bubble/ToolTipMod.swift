//
// ToolTipMod.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 31.10.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import SwiftUI

// MARK: - This modifier shows a lightweight tooltip bubble without intercepting hit tests.
struct ToolTipMod: ViewModifier {
    @Binding var isVisible: Bool
    let text: String
    let position: CGPoint

    // MARK: -
    func body(content: Content) -> some View {
        ZStack(alignment: .topLeading) {
            content
            if isVisible {
                TooltipBubble(text: text, position: position)
                    .transition(.opacity)
                    .allowsHitTesting(false)  // Only on the tooltip bubble, not on content below
            }
        }
        .animation(.easeInOut(duration: 0.12), value: isVisible)
    }

    // MARK: -
    private struct TooltipBubble: View {
        let text: String
        let position: CGPoint

        // MARK: -
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
