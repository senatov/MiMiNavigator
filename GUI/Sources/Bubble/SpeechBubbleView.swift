    //
    //  SpeechBubbleView.swift
    //  MiMiNavigator
    //
    //  Created by Iakov Senatov on 31.10.2025.
    //  Copyright © 2025 Senatov. All rights reserved.
    //

import Foundation
import SwiftUI

    // MARK: - Bubble view

    /// A stylable speech bubble view with configurable background, stroke, tail and content insets.
public struct SpeechBubbleView<Content: View>: View {
        // Style
    public var background: Color
    public var strokeColor: Color
    public var strokeWidth: CGFloat
    public var shadowRadius: CGFloat
    public var shadowOffset: CGSize
    
        // Shape
    public var cornerRadius: CGFloat
    public var tailLength: CGFloat
    public var tailWidth: CGFloat
    public var tailDirection: SpeechBubbleShape.Direction
    public var tailOffset: CGFloat
    
        // Content
    public var contentInsets: EdgeInsets
    @ViewBuilder public var content: () -> Content
    
    public init(
        background: Color = Color.white,
        strokeColor: Color = Color.black.opacity(0.6),
        strokeWidth: CGFloat = 0.8,
        shadowRadius: CGFloat = 10,
        shadowOffset: CGSize = CGSize(width: 0, height: 3),
        cornerRadius: CGFloat = 14,
        tailLength: CGFloat = 36,
        tailWidth: CGFloat = 16,
        tailDirection: SpeechBubbleShape.Direction = .left,
        tailOffset: CGFloat = 0,
        contentInsets: EdgeInsets = EdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14),
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.background = background
        self.strokeColor = strokeColor
        self.strokeWidth = strokeWidth
        self.shadowRadius = shadowRadius
        self.shadowOffset = shadowOffset
        self.cornerRadius = cornerRadius
        self.tailLength = tailLength
        self.tailWidth = tailWidth
        self.tailDirection = tailDirection
        self.tailOffset = tailOffset
        self.contentInsets = contentInsets
        self.content = content
    }
    
    public var body: some View {
        let shape = SpeechBubbleShape(
            cornerRadius: cornerRadius,
            tailLength: tailLength,
            tailWidth: tailWidth,
            tailDirection: tailDirection,
            tailOffset: tailOffset
        )
        
        ZStack {
            shape
                .fill(background) // keep caller's alpha; defaults are opaque
                .overlay(
                    shape.stroke(strokeColor.opacity(0.9), lineWidth: strokeWidth * 1.2)
                        .shadow(color: .black.opacity(0.25), radius: 2, x: 1, y: 1)
                )
            content()
                .padding(contentInsetsForTail(base: contentInsets))
            Rectangle()
                .fill(LinearGradient(colors: [Color.white.opacity(0.2), Color.clear], startPoint: .topLeading, endPoint: .bottomTrailing))
                .clipShape(shape)
        }
        .shadow(radius: shadowRadius, x: shadowOffset.width, y: shadowOffset.height)
        .drawingGroup()  // keep edges crisp under scaling
    }
    
        // Adds extra padding on the tail side so content does not overlap the tail base.
    private func contentInsetsForTail(base: EdgeInsets) -> EdgeInsets {
        var i = base
        switch tailDirection {
            case .left: i.leading += tailLength * 0.6
            case .right: i.trailing += tailLength * 0.6
            case .top: i.top += tailLength * 0.6
            case .bottom: i.bottom += tailLength * 0.6
        }
        return i
    }
}

    // MARK: - Convenience initializers
extension SpeechBubbleView where Content == Text {
        /// Convenience initializer for text content.
    public init(
        _ text: String,
        background: Color = Color.white,
        strokeColor: Color = Color.black.opacity(0.6),
        strokeWidth: CGFloat = 0.8,
        shadowRadius: CGFloat = 10,
        shadowOffset: CGSize = CGSize(width: 0, height: 3),
        cornerRadius: CGFloat = 14,
        tailLength: CGFloat = 36,
        tailWidth: CGFloat = 16,
        tailDirection: SpeechBubbleShape.Direction = .left,
        tailOffset: CGFloat = 0,
        textFont: Font = .custom("Arial", size: 18),
        textColor: Color = Color(.sRGB, red: 0.08, green: 0.18, blue: 0.45, opacity: 1.0),
        contentInsets: EdgeInsets = EdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14)
    ) {
        self.init(
            background: background,
            strokeColor: strokeColor,
            strokeWidth: strokeWidth,
            shadowRadius: shadowRadius,
            shadowOffset: shadowOffset,
            cornerRadius: cornerRadius,
            tailLength: tailLength,
            tailWidth: tailWidth,
            tailDirection: tailDirection,
            tailOffset: tailOffset,
            contentInsets: contentInsets
        ) {
            Text(text)
                .font(textFont)
                .monospacedDigit()
                .foregroundStyle(textColor)
        }
    }
}
