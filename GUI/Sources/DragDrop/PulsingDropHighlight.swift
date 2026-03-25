// PulsingDropHighlight.swift
// MiMiNavigator
//
// Created on 25.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Pulsing highlight animation for drag-drop target directories

import SwiftUI


// MARK: - PulsingDropHighlight
/// Pulsating blue glow on directory rows when they are drop targets.
struct PulsingDropHighlight: View {
    @State private var pulse = false


    private let fillColor = Color.accentColor.opacity(0.15)
    private let borderColor = Color.orange
    private let pulseRange: ClosedRange<Double> = 0.4...1.7


    var body: some View {
        log.debug(#function)
        return RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(fillColor)
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(.yellow, lineWidth: 2.5)
                    .opacity(pulse ? pulseRange.upperBound : pulseRange.lowerBound)
            )
            .onAppear {
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
    }
}
