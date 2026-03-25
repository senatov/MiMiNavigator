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
    @State private var pulse = false

    private let cornerRadius: CGFloat = 6
    private let fillRange: ClosedRange<Double> = 0.18...0.32

    var body: some View {
        log.debug(#function)

        return RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.yellow.opacity(pulse ? fillRange.upperBound : fillRange.lowerBound))
            .compositingGroup()
            .onAppear {
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
    }
}
