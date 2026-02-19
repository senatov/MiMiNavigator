// ResizableDivider.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 27.01.2026.
// Refactored: 17.02.2026
// Copyright © 2026 Senatov. All rights reserved.
// Description: Draggable divider for resizing table columns
//   - Drag updates binding in real-time but saves (onEnd) only on mouse-up
//   - Double-click triggers auto-fit callback

import SwiftUI

// MARK: - Resizable Divider
struct ResizableDivider: View {
    @Binding var width: CGFloat
    let min: CGFloat
    let max: CGFloat
    /// Called only on mouse-up (saves to UserDefaults)
    let onEnd: () -> Void
    /// Called on double-click; returns optimal width for the column
    var onAutoFit: (() -> CGFloat)? = nil

    @State private var isHovering = false
    @State private var isDragging = false
    @State private var dragStartWidth: CGFloat = 0
    /// Absolute X where drag started (global coordinates)
    @State private var dragStartX: CGFloat = 0

    var body: some View {
        ColumnSeparator()
            .frame(width: ColumnSeparatorStyle.activeWidth)
            .overlay {
                if isHovering || isDragging {
                    Rectangle()
                        .fill(isDragging ? ColumnSeparatorStyle.dragColor : ColumnSeparatorStyle.hoverColor)
                        .frame(width: ColumnSeparatorStyle.activeWidth)
                        .allowsHitTesting(false)
                }
            }
            .overlay {
                Color.clear
                    .frame(width: 14)
                    .contentShape(Rectangle())
                    .gesture(dragGesture)
                    .simultaneousGesture(doubleTapGesture)
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.1)) {
                            isHovering = hovering
                        }
                        if hovering {
                            NSCursor.resizeLeftRight.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
            }
    }

    // MARK: - Drag using global coordinates to avoid feedback-loop oscillation
    // When binding updates cause layout shift, DragGesture in local coords
    // recalculates translation relative to the new view position → oscillation.
    // Using .global coordinate space, translation is absolute and stable.
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .global)
            .onChanged { value in
                if !isDragging {
                    isDragging = true
                    dragStartWidth = width
                    dragStartX = value.startLocation.x
                }
                // Absolute delta from start position — not affected by view relayout
                let currentX = value.location.x
                let delta = -(currentX - dragStartX)
                let newWidth = dragStartWidth + delta
                width = Swift.min(Swift.max(newWidth, min), max)
            }
            .onEnded { _ in
                isDragging = false
                onEnd()
                log.debug("[ResizableDivider] drag ended, width=\(width)")
            }
    }

    // MARK: - Double-tap: auto-fit column width
    private var doubleTapGesture: some Gesture {
        TapGesture(count: 2)
            .onEnded {
                guard let autoFit = onAutoFit else { return }
                let optimal = Swift.min(Swift.max(autoFit(), min), max)
                width = optimal
                onEnd()
                log.debug("[ResizableDivider] auto-fit, width=\(optimal)")
            }
    }
}
