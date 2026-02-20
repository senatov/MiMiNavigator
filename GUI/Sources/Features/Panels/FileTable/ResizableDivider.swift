// ResizableDivider.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 27.01.2026.
// Refactored: 20.02.2026 — fix drag direction, fix hit-testing, fix gesture conflict
// Copyright © 2026 Senatov. All rights reserved.
// Description: Draggable divider for resizing table columns.
//   Visual line = 1pt (ColumnSeparatorStyle.width).
//   Hit area = 14pt transparent overlay via ZStack (does NOT affect layout).
//   Drag RIGHT → column widens. Drag LEFT → column narrows.
//   Double-click → auto-fit (if onAutoFit provided).

import SwiftUI

// MARK: - Resizable Divider
struct ResizableDivider: View {
    @Binding var width: CGFloat
    let min: CGFloat
    let max: CGFloat
    /// Called on mouse-up (saves to UserDefaults)
    let onEnd: () -> Void
    /// Optional: returns optimal auto-fit width on double-click
    var onAutoFit: (() -> CGFloat)? = nil

    @State private var isHovering: Bool = false
    @State private var isDragging: Bool = false
    @State private var dragStartWidth: CGFloat = 0
    @State private var dragStartX: CGFloat = 0
    @State private var lastTapTime: Date = .distantPast

    var body: some View {
        // Layout footprint = ColumnSeparatorStyle.width (1pt) — same as ColumnSeparator in rows.
        // Hit area is an overlay: does NOT affect layout width.
        Rectangle()
            .fill(lineColor)
            .frame(width: ColumnSeparatorStyle.width)
            .allowsHitTesting(false)
            .overlay {
                // 14pt transparent hit zone — overlay, zero layout impact
                Color.clear
                    .frame(width: 14)
                    .contentShape(Rectangle())
                    .gesture(dragGesture)
                    .onHover { hovering in
                        isHovering = hovering
                        if hovering {
                            NSCursor.resizeLeftRight.push()
                        } else {
                            NSCursor.pop()
                            if isDragging {
                                isDragging = false
                                onEnd()
                            }
                        }
                    }
            }
    }

    // MARK: - Line color
    private var lineColor: Color {
        if isDragging { return ColumnSeparatorStyle.dragColor }
        if isHovering { return ColumnSeparatorStyle.hoverColor }
        return ColumnSeparatorStyle.color
    }

    // MARK: - Drag gesture (global coordinates)
    // Layout: [col content] [Divider = RIGHT edge of col]
    // Drag RIGHT (+delta) → col widens
    // Drag LEFT  (-delta) → col narrows
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .global)
            .onChanged { value in
                let now = Date()
                let travel = abs(value.translation.width) + abs(value.translation.height)
                if travel < 4, now.timeIntervalSince(lastTapTime) < 0.35 {
                    if let autoFit = onAutoFit {
                        let optimal = Swift.min(Swift.max(autoFit(), min), max)
                        width = optimal
                        onEnd()
                        isDragging = false
                        log.debug("[ResizableDivider] auto-fit width=\(optimal)")
                    }
                    return
                }

                if !isDragging {
                    isDragging = true
                    dragStartWidth = width
                    dragStartX = value.startLocation.x
                    lastTapTime = now
                }

                // Drag RIGHT = col widens, no negation
                let delta = value.location.x - dragStartX
                let newWidth = dragStartWidth + delta
                width = Swift.min(Swift.max(newWidth, min), max)
            }
            .onEnded { _ in
                guard isDragging else { return }
                isDragging = false
                onEnd()
                log.debug("[ResizableDivider] drag ended width=\(width)")
            }
    }
}
