//
//  MediaInfoConvertButton.swift
//  MiMiNavigator
//
//  Copyright © 2026 Senatov. All rights reserved.
//

import SwiftUI

// MARK: - MediaInfoConvertButton

struct MediaInfoConvertButton: View {
    let isEnabled: Bool
    let action: () -> Void
    @State private var isHovered = false

    // MARK: - Body

    var body: some View {
        Button(action: action) {
            Label("Convert", systemImage: "arrow.triangle.2.circlepath")
                .font(.system(size: 13, weight: .bold))
                .lineLimit(1)
                .frame(minWidth: 118)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .foregroundStyle(isEnabled ? Color.white : Color.secondary)
                .background(buttonBackground)
                .overlay(buttonBorder)
                .shadow(color: shadowColor, radius: isHovered ? 10 : 6, y: isHovered ? 5 : 3)
                .scaleEffect(isHovered && isEnabled ? 1.04 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .focusable(false)
        .help("Convert")
        .onHover { hovering in
            withAnimation(.spring(response: 0.22, dampingFraction: 0.72)) {
                isHovered = hovering
            }
        }
    }

    // MARK: - Background

    private var buttonBackground: some View {
        RoundedRectangle(cornerRadius: 13, style: .continuous)
            .fill(isEnabled ? enabledGradient : disabledGradient)
    }

    private var buttonBorder: some View {
        RoundedRectangle(cornerRadius: 13, style: .continuous)
            .strokeBorder(Color.white.opacity(isEnabled ? 0.45 : 0.25), lineWidth: 1)
    }

    private var enabledGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(nsColor: NSColor.systemBlue),
                Color(nsColor: NSColor.systemTeal),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var disabledGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(nsColor: NSColor.windowBackgroundColor).opacity(0.65),
                Color(nsColor: NSColor.controlBackgroundColor).opacity(0.85),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var shadowColor: Color {
        isEnabled ? Color(nsColor: NSColor.systemBlue).opacity(0.32) : Color.black.opacity(0.08)
    }
}
