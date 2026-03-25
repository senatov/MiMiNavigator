//
//  LiquidGlassButtonStyle.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 25.03.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//  Descr: deep 3D glass pebble — multi-layer convex, animated icon on select

import SwiftUI

// MARK: - LiquidGlassButtonStyle
struct LiquidGlassButtonStyle: ButtonStyle {

    var isHighlighted: Bool = false

    // MARK: - iconColor
    var iconColor: Color {
        isHighlighted
            ? Color(#colorLiteral(red: 0.96, green: 0.10, blue: 0.12, alpha: 1))
            : Color(#colorLiteral(red: 0.521568656, green: 0.1098039225, blue: 0.05098039284, alpha: 1))
    }

    // MARK: - makeBody
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            // ── layer 1: deep violet or neutral base ──
            .background(
                isHighlighted
                    ? AnyShapeStyle(
                        LinearGradient(
                            colors: [
                                Color(#colorLiteral(red: 1, green: 0.8082827781, blue: 0.8750300931, alpha: 1)),
                                Color(#colorLiteral(red: 0.7170629799, green: 0.5761168817, blue: 0.9715820313, alpha: 1)),
                                Color(#colorLiteral(red: 0.6521054361, green: 0.504282305, blue: 0.9057421875, alpha: 1))
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    : AnyShapeStyle(
                        Color(#colorLiteral(red: 0.78, green: 0.78, blue: 0.78, alpha: 0.8))
                    )
            )
            // ── layer 2: glass material ──
            .background(.ultraThinMaterial)
            // ── layer 3: convex top-lit highlight ──
            .overlay(
                LinearGradient(
                    colors: [
                        Color.white.opacity(isHighlighted ? 0.40 : 0.55),
                        Color.clear,
                        Color.black.opacity(0.15)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .blendMode(.overlay)
            )
            // ── layer 4: specular glint top-left ──
            .overlay(
                RadialGradient(
                    colors: [
                        Color.white.opacity(isHighlighted ? 0.50 : 0.35),
                        Color.clear
                    ],
                    center: UnitPoint(x: 0.25, y: 0.18),
                    startRadius: 0,
                    endRadius: 18
                )
                .blendMode(.screen)
            )
            .clipShape(PebbleShape())
            // ── layer 5: refraction edge ring ──
            .overlay(
                PebbleShape().stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            .white.opacity(0.7), .white.opacity(0.08),
                            .white.opacity(0.5), .white.opacity(0.08),
                            .white.opacity(0.7)
                        ]),
                        center: .center
                    ),
                    lineWidth: 0.8
                )
                .opacity(isHighlighted ? 0.75 : 0.5)
            )
            // ── layer 6: inner shadow for depth ──
            .overlay(
                PebbleShape()
                    .stroke(Color.black.opacity(0.20), lineWidth: 1.5)
                    .blur(radius: 1.5)
                    .clipShape(PebbleShape())
            )
            // ── drop shadows for 3D convexity ──
            .shadow(color: .black.opacity(0.28), radius: 2, x: 0.8, y: 2)
            .shadow(color: .white.opacity(0.45), radius: 1, x: -0.4, y: -0.6)
            // ── press + highlight animation ──
            .scaleEffect(configuration.isPressed ? 0.90 : 1)
            .animation(.bouncy, value: configuration.isPressed)
            .animation(.easeInOut(duration: 0.2), value: isHighlighted)
    }
}
