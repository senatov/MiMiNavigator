// ThumbnailSizeSlider.swift
// MiMiNavigator
//
// Created by Claude on 10.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Custom slider for thumbnail cell size — macOS Sound-panel style.
//   Rounded track with soft fill, knob with 3D look, grid icons on edges.
//   Uses local @State during drag to avoid UserDefaults write-storm.

import SwiftUI

// MARK: - ThumbnailSizeSlider

struct ThumbnailSizeSlider: View {

    @Binding var value: CGFloat
    let range: ClosedRange<CGFloat>
    let accentColor: Color

    // Local drag state — prevents UserDefaults write on every pixel
    @State private var isDragging = false
    @State private var dragValue: CGFloat = 0

    // Layout
    private let trackWidth: CGFloat = 130
    private let trackHeight: CGFloat = 5
    private let knobDiameter: CGFloat = 16
    private let totalHeight: CGFloat = 22

    /// The displayed value: local dragValue while dragging, bound value otherwise
    private var displayValue: CGFloat {
        isDragging ? dragValue : value
    }

    /// Normalized 0…1
    private var fraction: CGFloat {
        let v = displayValue
        let clamped = min(max(v, range.lowerBound), range.upperBound)
        return (clamped - range.lowerBound) / (range.upperBound - range.lowerBound)
    }

    /// Track fill — visible but not screaming, uses theme accent
    private var trackFillColor: Color {
        accentColor.opacity(0.55)
    }
    private var trackBgColor: Color {
        Color(nsColor: .separatorColor).opacity(0.4)
    }

    private func snap(_ v: CGFloat) -> CGFloat {
        (v / 10).rounded() * 10
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
                    // Background track — with subtle inner shadow via overlay
                    Capsule()
                        .fill(trackBgColor)
                        .overlay(
                            Capsule()
                                .stroke(Color.black.opacity(0.08), lineWidth: 0.5)
                        )
                        .frame(height: trackHeight)

                    // Filled portion — solid gradient, crisp edges
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    trackFillColor.opacity(0.9),
                                    trackFillColor,
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .overlay(
                            Capsule()
                                .stroke(accentColor.opacity(0.15), lineWidth: 0.5)
                        )
                        .frame(width: max(trackHeight, knobX), height: trackHeight)

                    // Knob — crisp 3D, larger for easy grabbing
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white,
                                    Color(nsColor: .controlColor),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(
                            Circle()
                                .stroke(Color(nsColor: .separatorColor).opacity(0.7), lineWidth: 0.75)
                        )
                        .shadow(color: .black.opacity(0.22), radius: 2, x: 0, y: 1)
                        .shadow(color: .white.opacity(0.6), radius: 0.5, x: 0, y: -0.5)
                        .frame(width: knobDiameter, height: knobDiameter)
                        .offset(x: knobX - knobDiameter / 2)
                }
                .frame(height: totalHeight)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { drag in
                            if !isDragging {
                                isDragging = true
                                dragValue = value
                            }
                            let newFraction = (drag.location.x - knobDiameter / 2) / usableWidth
                            let clamped = min(max(newFraction, 0), 1)
                            let raw = range.lowerBound + clamped * (range.upperBound - range.lowerBound)
                            dragValue = snap(raw)
                        }
                        .onEnded { _ in
                            // Commit to binding only once — triggers UserDefaults write + thumbnail resize
                            value = dragValue
                            isDragging = false
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
            Text("\(Int(displayValue)) pt")
                .monospacedDigit()
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 42, alignment: .leading)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 0.5)
        )
    }

    // MARK: - Step helper
    private func stepValue(by delta: CGFloat) {
        let newVal = snap(min(max(value + delta, range.lowerBound), range.upperBound))
        value = newVal
    }
}
