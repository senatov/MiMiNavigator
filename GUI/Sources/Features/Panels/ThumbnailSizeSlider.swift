// ThumbnailSizeSlider.swift
// MiMiNavigator
//
// Created by Claude on 10.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Custom slider for thumbnail cell size — macOS Sound-panel style.
//   Rounded track with soft fill, knob with 3D look, grid icons on edges.

import SwiftUI

// MARK: - ThumbnailSizeSlider

struct ThumbnailSizeSlider: View {

    @Binding var value: CGFloat
    let range: ClosedRange<CGFloat>
    let accentColor: Color

    // Layout
    private let trackWidth: CGFloat = 130      // ~30% wider than 100
    private let trackHeight: CGFloat = 6
    private let knobDiameter: CGFloat = 14
    private let totalHeight: CGFloat = 22

    /// Normalized 0…1
    private var fraction: CGFloat {
        let clamped = min(max(value, range.lowerBound), range.upperBound)
        return (clamped - range.lowerBound) / (range.upperBound - range.lowerBound)
    }

    /// Soft accent — muted version of theme accent, not screaming blue
    private var trackFillColor: Color {
        accentColor.opacity(0.35)
    }
    private var trackBgColor: Color {
        Color(nsColor: .separatorColor).opacity(0.25)
    }

    var body: some View {
        HStack(spacing: 6) {
            // Small grid icon (decrease button)
            Button {
                stepValue(by: -20)
            } label: {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Smaller thumbnails")

            // Custom track + knob
            GeometryReader { geo in
                let usableWidth = geo.size.width - knobDiameter
                let knobX = knobDiameter / 2 + usableWidth * fraction

                ZStack(alignment: .leading) {
                    // Background track (full width)
                    Capsule()
                        .fill(trackBgColor)
                        .frame(height: trackHeight)

                    // Filled portion
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    trackFillColor,
                                    trackFillColor.opacity(0.6),
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(trackHeight, knobX), height: trackHeight)

                    // Knob
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white,
                                    Color(nsColor: .controlBackgroundColor),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(
                            Circle()
                                .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 0.5)
                        )
                        .shadow(color: .black.opacity(0.18), radius: 1.5, x: 0, y: 1)
                        .frame(width: knobDiameter, height: knobDiameter)
                        .offset(x: knobX - knobDiameter / 2)
                }
                .frame(height: totalHeight)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { drag in
                            let newFraction = (drag.location.x - knobDiameter / 2) / usableWidth
                            let clamped = min(max(newFraction, 0), 1)
                            value = range.lowerBound + clamped * (range.upperBound - range.lowerBound)
                            // Snap to step of 10
                            value = (value / 10).rounded() * 10
                        }
                )
            }
            .frame(width: trackWidth, height: totalHeight)

            // Large grid icon (increase button)
            Button {
                stepValue(by: 20)
            } label: {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Larger thumbnails")

            // Size label
            Text("\(Int(value)) pt")
                .monospacedDigit()
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 42, alignment: .leading)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.4))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.2), lineWidth: 0.5)
        )
    }

    // MARK: - Step helper
    private func stepValue(by delta: CGFloat) {
        let newVal = min(max(value + delta, range.lowerBound), range.upperBound)
        value = (newVal / 10).rounded() * 10
    }
}
