// ParentStripButtonStyle.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 06.06.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Liquid Glass button styling for the parent-navigation strip.

import SwiftUI

// MARK: - ParentStripButtonStyle
struct ParentStripButtonStyle: ButtonStyle {
    let isHighlighted: Bool
    let isDropContact: Bool
    let keyboardPulse: Bool
    private let buttonShape = ParentStripButtonShape(topRadius: 3, bottomRadius: 11)
    func makeBody(configuration: Configuration) -> some View {
        let isPressed = configuration.isPressed
        let isLifted = isHighlighted || keyboardPulse
        configuration.label
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(buttonBackground)
            .glassEffect(.regular.tint(glassTint))
            .overlay(buttonHighlight)
            .overlay(specularGlint(isPressed: isPressed))
            .clipShape(buttonShape)
            .overlay(
                buttonShape
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(edgeOpacity(isPressed: isPressed)),
                                Color.black.opacity(isPressed ? 0.18 : 0.10)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: isLifted ? 0.9 : 0.75
                    )
            )
            .shadow(color: .black.opacity(shadowOpacity(isPressed: isPressed)), radius: shadowRadius(isPressed: isPressed), x: 0.8, y: shadowY(isPressed: isPressed))
            .scaleEffect(isPressed ? 0.982 : isDropContact ? 1.018 : keyboardPulse ? 1.016 : isHighlighted ? 1.006 : 1)
            .offset(y: isPressed ? 0.8 : isLifted ? -0.6 : 0)
            .saturation(isDropContact ? 1.45 : isLifted ? 1.12 : 1)
            .brightness(isPressed ? -0.035 : isDropContact ? 0.08 : isLifted ? 0.015 : 0)
            .animation(.smooth(duration: 0.16), value: isHighlighted)
            .animation(.interpolatingSpring(stiffness: 420, damping: 22), value: isDropContact)
            .animation(.interpolatingSpring(stiffness: 620, damping: 23), value: keyboardPulse)
            .animation(.interpolatingSpring(stiffness: 520, damping: 28), value: isPressed)
    }
    private var buttonBackground: some ShapeStyle {
        LinearGradient(
            colors: isDropContact
                ? [
                    Color(#colorLiteral(red: 0.34, green: 0.39, blue: 0.47, alpha: 0.92)),
                    Color(#colorLiteral(red: 0.20, green: 0.31, blue: 0.47, alpha: 0.94)),
                    Color(#colorLiteral(red: 0.12, green: 0.24, blue: 0.40, alpha: 0.96))
                ]
                : isHighlighted
                ? [
                    Color(#colorLiteral(red: 1, green: 0.98, blue: 0.88, alpha: 0.72)),
                    Color(#colorLiteral(red: 0.72, green: 0.84, blue: 1, alpha: 0.52)),
                    Color(#colorLiteral(red: 0.86, green: 0.78, blue: 1, alpha: 0.50))
                ]
                : [
                    Color(#colorLiteral(red: 0.93, green: 0.95, blue: 0.97, alpha: 0.62)),
                    Color(#colorLiteral(red: 0.72, green: 0.75, blue: 0.78, alpha: 0.46)),
                    Color(#colorLiteral(red: 0.88, green: 0.90, blue: 0.92, alpha: 0.54))
                ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    private var glassTint: Color {
        isDropContact
            ? Color(#colorLiteral(red: 0.42, green: 0.58, blue: 0.78, alpha: 0.42))
            : isHighlighted
            ? Color(#colorLiteral(red: 0.96, green: 0.98, blue: 1, alpha: 0.28))
            : Color(#colorLiteral(red: 1, green: 1, blue: 1, alpha: 0.14))
    }
    private var buttonHighlight: some View {
        LinearGradient(
            colors: [
                Color.white.opacity(isDropContact ? 0.58 : isHighlighted ? 0.68 : 0.56),
                Color.clear,
                Color.black.opacity(isDropContact ? 0.22 : isHighlighted ? 0.10 : 0.15)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .blendMode(.overlay)
    }
    private func specularGlint(isPressed: Bool) -> some View {
        RadialGradient(
            colors: [
                Color.white.opacity(isPressed ? 0.10 : isDropContact ? 0.38 : isHighlighted ? 0.34 : 0.18),
                Color.clear
            ],
            center: UnitPoint(x: isDropContact ? 0.50 : isHighlighted ? 0.82 : 0.70, y: 0.14),
            startRadius: 0,
            endRadius: isDropContact ? 70 : isHighlighted ? 42 : 28
        )
        .blendMode(.screen)
        .clipShape(buttonShape)
    }
    private func edgeOpacity(isPressed: Bool) -> Double {
        if isPressed { return 0.34 }
        if isDropContact { return 1 }
        return isHighlighted ? 0.86 : 0.44
    }
    private func shadowOpacity(isPressed: Bool) -> Double {
        if isPressed { return 0.18 }
        if isDropContact { return 0.34 }
        return isHighlighted ? 0.34 : 0.20
    }
    private func shadowRadius(isPressed: Bool) -> CGFloat {
        if isPressed { return 1.2 }
        if isDropContact { return 4 }
        return isHighlighted ? 3.2 : 2
    }
    private func shadowY(isPressed: Bool) -> CGFloat {
        if isPressed { return 0.8 }
        return isHighlighted ? 2.4 : 1.5
    }
}

// MARK: - ParentStripButtonShape
private struct ParentStripButtonShape: Shape {
    let topRadius: CGFloat
    let bottomRadius: CGFloat
    func path(in rect: CGRect) -> Path {
        let top = min(topRadius, rect.height / 2)
        let bottom = min(bottomRadius, rect.height / 2)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + top, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - top, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + top), control: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottom))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - bottom, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + bottom, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - bottom), control: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + top))
        path.addQuadCurve(to: CGPoint(x: rect.minX + top, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
