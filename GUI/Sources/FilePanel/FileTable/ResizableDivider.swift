// ResizableDivider.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 27.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Draggable divider for resizing table columns

import SwiftUI

// MARK: - Resizable Divider
/// Vertical divider that can be dragged to resize adjacent columns
struct ResizableDivider: View {
    @Binding var width: CGFloat
    let min: CGFloat
    let max: CGFloat
    let onEnd: () -> Void

    @State private var isHovering = false
    @State private var isDragging = false
    @State private var dragStartWidth: CGFloat = 0

    private var currentColor: Color {
        if isDragging {
            return ColumnSeparatorStyle.dragColor
        } else if isHovering {
            return ColumnSeparatorStyle.hoverColor
        }
        return ColumnSeparatorStyle.color
    }

    private var dividerLineWidth: CGFloat {
        (isHovering || isDragging) ? 2.0 : ColumnSeparatorStyle.width
    }

    var body: some View {
        Rectangle()
            .fill(currentColor)
            .frame(width: dividerLineWidth)
            .padding(.vertical, 2)
            .overlay {
                // Invisible wider hit area for easier grabbing
                Color.clear
                    .frame(width: 12)
                    .contentShape(Rectangle())
            }
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

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                if !isDragging {
                    isDragging = true
                    dragStartWidth = width
                }
                // Negative delta: drag divider RIGHT = column gets WIDER
                let delta = -value.translation.width
                let newWidth = dragStartWidth + delta
                width = Swift.min(Swift.max(newWidth, min), max)
            }
            .onEnded { _ in
                isDragging = false
                onEnd()
                log.debug("[ResizableDivider] drag ended, new width=\(width)")
            }
    }
}
