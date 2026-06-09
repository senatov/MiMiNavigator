//
// DuoPanelToolbarBackground.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 10.12.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import AppKit
import SwiftUI

// MARK: - Duo Panel Toolbar Background
/// Reusable bottom command toolbar background.
struct DuoPanelToolbarBackground: View {
    let cornerRadius: CGFloat

    // MARK: - Body
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(toolbarFill)
            .overlay(toolbarHighlight)
            .overlay(toolbarBorder)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.white.opacity(0.62))
                    .frame(height: 1)
            }
            .shadow(color: Color.white.opacity(0.42), radius: 1.2, y: -1)
            .shadow(color: Color.black.opacity(0.16), radius: 5, y: 2)
    }

    private var toolbarFill: some ShapeStyle {
        LinearGradient(
            stops: [
                .init(color: Color(#colorLiteral(red: 0.905, green: 0.925, blue: 0.952, alpha: 1)).opacity(0.76), location: 0),
                .init(color: Color(#colorLiteral(red: 0.765, green: 0.812, blue: 0.875, alpha: 1)).opacity(0.70), location: 0.68),
                .init(color: Color(#colorLiteral(red: 0.630, green: 0.700, blue: 0.790, alpha: 1)).opacity(0.66), location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var toolbarHighlight: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.78),
                        Color.white.opacity(0.12),
                        Color(#colorLiteral(red: 0.24, green: 0.34, blue: 0.50, alpha: 1)).opacity(0.16),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 0.9
            )
            .padding(0.8)
    }

    private var toolbarBorder: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .stroke(Color(#colorLiteral(red: 0.45, green: 0.55, blue: 0.68, alpha: 1)).opacity(0.70), lineWidth: 0.9)
    }
}
