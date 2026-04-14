//
// DownToolbarButtonView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 21.02.25.

import SwiftUI

// MARK: -
/// Bottom toolbar button with transparent glass styling, spring hover/press animation and depth shadow.
struct DownToolbarButtonView: View {
    let title: String
    let systemImage: String
    let action: () -> Void
    @State private var isHovered: Bool = false

    // MARK: -
    var body: some View {
        Button(action: {
            action()
        }) {
            Label(title, systemImage: systemImage)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(minWidth: 90)
                .symbolRenderingMode(.hierarchical)
        }
        .buttonStyle(DownToolbarGlassButtonStyle(isHovered: isHovered))
        .onHover { hovering in
            withAnimation(.spring(response: 0.22, dampingFraction: 0.72)) {
                isHovered = hovering
            }
        }
        .focusable(false)
        .help(title)
    }
}



struct DownToolbarGlassButtonStyle: ButtonStyle {
    let isHovered: Bool

    // MARK: -
    func makeBody(configuration: Configuration) -> some View {
        let isPressed = configuration.isPressed
        let scale = isPressed ? 0.972 : (isHovered ? 1.045 : 1.0)
        let shadowOpacity = isPressed ? 0.26 : (isHovered ? 0.22 : 0.12)
        let shadowRadius: CGFloat = isPressed ? 10 : (isHovered ? 12 : 6)
        let shadowYOffset: CGFloat = isPressed ? 5 : (isHovered ? 7 : 3)
        let highlightOpacity = isPressed ? 0.22 : (isHovered ? 0.34 : 0.26)
        let borderOpacity = isPressed ? 0.18 : (isHovered ? 0.24 : 0.16)
        let glassOpacity = isPressed ? 0.84 : (isHovered ? 0.94 : 0.88)
        let topGlowOpacity = isPressed ? 0.18 : (isHovered ? 0.28 : 0.20)
        let bottomEdgeOpacity = isPressed ? 0.20 : (isHovered ? 0.28 : 0.18)

        return configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Color.primary.opacity(isPressed ? 0.96 : 0.90))
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .opacity(glassOpacity)
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(topGlowOpacity),
                                    Color.white.opacity(0.08),
                                    Color.clear,
                                    Color.gray.opacity(0.09)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(Color.white.opacity(isHovered ? 0.05 : 0.03))
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(Color.white.opacity(highlightOpacity), lineWidth: 1)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(Color.black.opacity(borderOpacity), lineWidth: 1)
                    .padding(0.5)
            }
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.32), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 8)
                    .padding(.horizontal, 6)
                    .padding(.top, 2)
                    .blur(radius: 0.4)
            }
            .overlay(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.clear, Color.black.opacity(bottomEdgeOpacity)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 10)
                    .padding(.horizontal, 4)
                    .padding(.bottom, 1)
            }
            .shadow(color: Color.white.opacity(isHovered ? 0.16 : 0.08), radius: 1.5, y: -1)
            .shadow(color: Color.black.opacity(shadowOpacity), radius: shadowRadius, y: shadowYOffset)
            .scaleEffect(scale)
            .animation(.spring(response: 0.20, dampingFraction: 0.70), value: configuration.isPressed)
            .animation(.spring(response: 0.24, dampingFraction: 0.74), value: isHovered)
            .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
}
