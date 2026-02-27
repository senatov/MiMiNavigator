// ResizableDivider.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 27.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Draggable divider for resizing table columns.
//   Layout footprint = 1pt (same as ColumnSeparator in rows).
//   Hit area = 14pt wide transparent overlay (does NOT affect layout).
//   On hover: line becomes black, 2.5pt wide, with drop shadow — clear grab affordance.
//   On drag: line stays bold black until mouse-up.

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
    @State private var dragStartX: CGFloat = 0

    /// Active = hovering or dragging (grab affordance visible)
    private var isActive: Bool { isHovering || isDragging }

    var body: some View {
        ZStack {
            // Passive line — always visible, thin
            Rectangle()
                .fill(ColumnSeparatorStyle.color)
                .frame(width: ColumnSeparatorStyle.width)
                .allowsHitTesting(false)

            // Active line — bold black with shadow, only during hover/drag
            if isActive {
                Rectangle()
                    .fill(Color.black)
                    .frame(width: 2.5)
                    .shadow(color: Color.black.opacity(0.4), radius: 2, x: 0, y: 0)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .frame(width: ColumnSeparatorStyle.width)
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

    // MARK: - Drag (global coordinates to avoid feedback-loop oscillation)

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .global)
            .onChanged { value in
                if !isDragging {
                    isDragging = true
                    dragStartWidth = width
                    dragStartX = value.startLocation.x
                }
                let delta = -(value.location.x - dragStartX)
                let newWidth = dragStartWidth + delta
                width = Swift.min(Swift.max(newWidth, min), max)
            }
            .onEnded { _ in
                isDragging = false
                onEnd()
            }
    }

    // MARK: - Double-tap: auto-fit

    private var doubleTapGesture: some Gesture {
        TapGesture(count: 2)
            .onEnded {
                guard let autoFit = onAutoFit else { return }
                let optimal = Swift.min(Swift.max(autoFit(), min), max)
                width = optimal
                onEnd()
            }
    }
}
