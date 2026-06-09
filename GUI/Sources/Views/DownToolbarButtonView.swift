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
        let scale = isPressed ? 0.976 : (isHovered ? 1.028 : 1.0)
        let shadowOpacity = isPressed ? 0.30 : (isHovered ? 0.28 : 0.18)
        let shadowRadius: CGFloat = isPressed ? 7 : (isHovered ? 9 : 5)
        let shadowYOffset: CGFloat = isPressed ? 4 : (isHovered ? 5 : 3)
        let highlightOpacity = isPressed ? 0.24 : (isHovered ? 0.42 : 0.32)
        let borderOpacity = isPressed ? 0.28 : (isHovered ? 0.38 : 0.30)
        let glassOpacity = isPressed ? 0.78 : (isHovered ? 0.88 : 0.82)
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
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(#colorLiteral(red: 0.94, green: 0.97, blue: 1.0, alpha: 1)),
                                    Color(#colorLiteral(red: 0.78, green: 0.83, blue: 0.90, alpha: 1)),
                                    Color(#colorLiteral(red: 0.61, green: 0.69, blue: 0.80, alpha: 1)),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .opacity(glassOpacity)
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(topGlowOpacity),
                                    Color.white.opacity(0.05),
                                    Color.clear,
                                    Color(#colorLiteral(red: 0.22, green: 0.32, blue: 0.48, alpha: 1)).opacity(0.08)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(Color.white.opacity(isHovered ? 0.07 : 0.035))
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(Color.white.opacity(highlightOpacity), lineWidth: 1)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(Color(#colorLiteral(red: 0.31, green: 0.42, blue: 0.57, alpha: 1)).opacity(borderOpacity), lineWidth: 1)
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
                            colors: [Color.clear, Color(#colorLiteral(red: 0.12, green: 0.18, blue: 0.28, alpha: 1)).opacity(bottomEdgeOpacity)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 10)
                    .padding(.horizontal, 4)
                    .padding(.bottom, 1)
            }
            .shadow(color: Color.white.opacity(isHovered ? 0.26 : 0.16), radius: 1.5, y: -1)
            .shadow(color: Color.black.opacity(shadowOpacity), radius: shadowRadius, y: shadowYOffset)
            .scaleEffect(scale)
            .animation(.spring(response: 0.20, dampingFraction: 0.70), value: configuration.isPressed)
            .animation(.spring(response: 0.24, dampingFraction: 0.74), value: isHovered)
            .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
}
