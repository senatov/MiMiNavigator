// PulsingDropHighlight.swift
// MiMiNavigator
//
// Created on 25.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Pulsing highlight animation for drag-drop target directories

import SwiftUI

// MARK: - PulsingDropHighlight
/// Yellow background highlight for drop target directory rows.
struct PulsingDropHighlight: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false
    private let cornerRadius: CGFloat = 6

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.accentColor.opacity(pulse && !reduceMotion ? 0.26 : 0.16))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.accentColor.opacity(0.82), lineWidth: pulse && !reduceMotion ? 2 : 1)
            }
            .scaleEffect(pulse && !reduceMotion ? 1.008 : 1)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.smooth(duration: 0.7).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
            .onDisappear {
                pulse = false
            }
    }
}
