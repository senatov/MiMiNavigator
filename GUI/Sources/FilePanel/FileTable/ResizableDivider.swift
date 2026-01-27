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
    
    private var dividerWidth: CGFloat {
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        return Swift.max(1.0 / scale, 1.0)
    }
    
    var body: some View {
        Rectangle()
            .fill(Color(red: 0.1, green: 0.15, blue: 0.4))
            .frame(width: dividerWidth)
            .padding(.vertical, 2)
            .overlay {
                Color.clear
                    .frame(width: 12)
                    .contentShape(Rectangle())
            }
            .gesture(dragGesture)
            .onHover { hovering in
                isHovering = hovering
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
                let delta = value.translation.width
                let newWidth = width - delta
                width = Swift.min(Swift.max(newWidth, min), max)
            }
            .onEnded { _ in
                onEnd()
            }
    }
}
