//
// DuoPanelToolbarBackground.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 10.12.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import AppKit
import SwiftUI

/// Reusable toolbar background with glass effect and decorative borders
struct DuoPanelToolbarBackground: View {
    let cornerRadius: CGFloat
    
    /// One physical pixel width for the current display
    private var px: CGFloat {
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        return 1.0 / scale
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.ultraThinMaterial)
            // Decorative hairline ring (crisp, gradient)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.30),  // top highlight
                                Color.blue.opacity(0.08),
                                Color.black.opacity(0.12),  // bottom subtle shadow
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: px
                    )
            )
            // Soft top glow
            .overlay(alignment: .top) {
                LinearGradient(
                    colors: [Color.white.opacity(0.22), Color.blue.opacity(0.08), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 20)
            }
            // Crisp bottom hairline
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.40),  // upper edge highlight
                                Color.white.opacity(0.18),
                                Color.black.opacity(0.20),  // lower subtle shadow
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: px)
                    .padding(.horizontal, 0.5)
                    .allowsHitTesting(false)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: Color.black.opacity(0.10), radius: 8, x: 0, y: 2)
            .shadow(color: Color.blue.opacity(0.06), radius: 18, x: 0, y: 10)
    }
}
