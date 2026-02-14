// ResizableDivider.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 27.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Draggable divider for resizing table columns

import SwiftUI

// MARK: - Resizable Divider
/// Vertical divider that can be dragged to resize adjacent columns
/// Resizable column divider for header.
/// Uses the SAME ColumnSeparator as row dividers to guarantee identical layout,
/// with an invisible overlay for drag gesture hit area.
struct ResizableDivider: View {
    @Binding var width: CGFloat
    let min: CGFloat
    let max: CGFloat
    let onEnd: () -> Void

    @State private var isHovering = false
    @State private var isDragging = false
    @State private var dragStartWidth: CGFloat = 0

    var body: some View {
        // Use exactly the same ColumnSeparator as rows — guarantees identical layout
        ColumnSeparator()
            .overlay {
                // Hover/drag color feedback (does not affect layout)
                if isHovering || isDragging {
                    Rectangle()
                        .fill(isDragging ? ColumnSeparatorStyle.dragColor : ColumnSeparatorStyle.hoverColor)
                        .frame(width: 2)
                        .allowsHitTesting(false)
                }
            }
            .overlay {
                // Wide invisible hit area for dragging (does not affect layout)
                Color.clear
                    .frame(width: 14)
                    .contentShape(Rectangle())
                    .gesture(dragGesture)
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

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                if !isDragging {
                    isDragging = true
                    dragStartWidth = width
                }
                let delta = -value.translation.width
                let newWidth = dragStartWidth + delta
                width = Swift.min(Swift.max(newWidth, min), max)
            }
            .onEnded { _ in
                isDragging = false
                onEnd()
                log.debug("\(#function) [ResizableDivider] drag ended, new width=\(width)")
            }
    }
}
