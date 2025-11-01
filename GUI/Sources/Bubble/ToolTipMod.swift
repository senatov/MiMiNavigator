//
//  ToolTipMod.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 31.10.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

//
//  ToolTipMod.swift
//  MiMiNavigator
//
//  A lightweight tooltip overlay (modifier + view) that isolates
//  tooltip redraws from the rest of the layout.
//  Uses SpeechBubbleView (comic-style white opaque bubble with tail).
//

import AppKit
import SwiftUI

// MARK: - Public Modifier

/// Use as:
/// .modifier(ToolTipMod(isVisible: $isVisible, text: text, position: point))
@MainActor
public struct ToolTipMod: ViewModifier {

    // External state (Bindings to avoid duplicating app state)
    @Binding var isVisible: Bool
    var text: String
    var position: CGPoint
    var config: ToolTipConfig

    public init(isVisible: Binding<Bool>, text: String, position: CGPoint, config: ToolTipConfig = .default) {
        self._isVisible = isVisible
        self.text = text
        self.position = position
        self.config = config
    }

    public func body(content: Content) -> some View {
        ZStack {
            content

            // Overlay is always in the tree; visibility is animated (no layout impact)
            TooltipOverlayView(text: text, position: position, config: config)
                .opacity(isVisible ? 1 : 0)
                .scaleEffect(isVisible ? 1.0 : 0.86)
                .zIndex(1000)
                .allowsHitTesting(false)
                .animation(.easeInOut(duration: 0.22), value: isVisible)
                .transition(.opacity.combined(with: .slide))
        }
    }
}

// MARK: - Overlay View

/// A self-contained overlay that draws a SpeechBubbleView at a given position.
@MainActor
public struct TooltipOverlayView: View {
    let text: String
    let position: CGPoint
    let config: ToolTipConfig

    public init(text: String, position: CGPoint, config: ToolTipConfig) {
        self.text = text
        self.position = position
        self.config = config
    }

    public var body: some View {
        // Snap position to pixel grid for crisp movement
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        let snapped = CGPoint(
            x: (position.x * scale).rounded() / scale,
            y: (position.y * scale).rounded() / scale
        )

        SpeechBubbleView(
            text,
            cornerRadius: config.cornerRadius,
            tailLength: config.tailLength,
            tailWidth: config.tailWidth,
            tailDirection: config.tailDirection,
            tailOffset: config.tailOffset
        )
        .frame(width: config.size.width, height: config.size.height)
        .position(snapped)
        .compositingGroup()  // isolate compositing
        .drawingGroup()  // flatten vector layers for smoother updates
        .shadow(radius: 18, x: 0, y: 3)
        .animation(nil, value: position)
        .accessibilityHidden(true)
    }
}
