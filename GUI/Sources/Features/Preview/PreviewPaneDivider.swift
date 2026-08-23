// PreviewPaneDivider.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 23.08.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: HIG-aligned resize separator for the workspace Preview pane.

import SwiftUI

// MARK: - Preview Pane Divider
struct PreviewPaneDivider: View {
    @Binding var previewWidth: CGFloat
    @State private var initialWidth: CGFloat?
    @State private var isHovering = false
    let availableWidth: CGFloat
    private var maximumWidth: CGFloat {
        min(PreviewPaneStore.maximumWidth, max(PreviewPaneStore.minimumWidth, availableWidth * 0.46))
    }

    // MARK: - Body
    var body: some View {
        Rectangle()
            .fill(isHovering || initialWidth != nil ? Color.accentColor.opacity(0.7) : Color(nsColor: .separatorColor))
            .frame(width: isHovering || initialWidth != nil ? 2 : 1)
            .frame(width: 7)
            .contentShape(Rectangle())
            .onHover { hovering in
                isHovering = hovering
                if hovering { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let start = initialWidth ?? previewWidth
                        initialWidth = start
                        previewWidth = min(max(start - value.translation.width, PreviewPaneStore.minimumWidth), maximumWidth)
                    }
                    .onEnded { _ in initialWidth = nil }
            )
            .accessibilityLabel("Resize Preview pane")
    }
}
