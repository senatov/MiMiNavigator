    //
    //  SpeechBubbleShape.swift
    //  MiMiNavigator
    //
    //  Created by Iakov Senatov on 31.10.2025.
    //  Copyright © 2025 Senatov. All rights reserved.
    //


    //
    //  SpeechBubbleView.swift
    //  Reusable speech bubble with a tail for tooltips/chat balloons
    //

import SwiftUI

    // MARK: - Tail shape

    /// A speech bubble shape with a configurable tail.
public struct SpeechBubbleShape: Shape {
    public enum Direction: Sendable {
        case left, right, top, bottom
    }
    
    public var cornerRadius: CGFloat
    public var tailLength: CGFloat
    public var tailWidth: CGFloat
    public var tailDirection: Direction
        /// Offset along the edge in points (0 = centered on that edge).
    public var tailOffset: CGFloat
    
    public init(
        cornerRadius: CGFloat = 14,
        tailLength: CGFloat = 36,     // longer tail by default
        tailWidth: CGFloat = 16,
        tailDirection: Direction = .left,
        tailOffset: CGFloat = 0
    ) {
        self.cornerRadius = cornerRadius
        self.tailLength = tailLength
        self.tailWidth = tailWidth
        self.tailDirection = tailDirection
        self.tailOffset = tailOffset
    }
    
    public func path(in rect: CGRect) -> Path {
            // Base rounded rect
        let bubbleRect = rect
        var path = Path(roundedRect: bubbleRect, cornerRadius: cornerRadius)
        
            // Compute tail triangle points inside rect; caller should allocate enough space.
        let halfTail = tailWidth / 2
        
        switch tailDirection {
            case .left:
                    // Tail points outward to the left edge.
                let midY = bubbleRect.midY + tailOffset
                let baseTop = CGPoint(x: bubbleRect.minX + cornerRadius, y: max(bubbleRect.minY + cornerRadius, midY - halfTail))
                let baseBot = CGPoint(x: bubbleRect.minX + cornerRadius, y: min(bubbleRect.maxY - cornerRadius, midY + halfTail))
                let tip     = CGPoint(x: bubbleRect.minX - tailLength, y: midY)
                path.move(to: baseTop)
                path.addLine(to: tip)
                path.addLine(to: baseBot)
                path.closeSubpath()
                
            case .right:
                let midY = bubbleRect.midY + tailOffset
                let baseTop = CGPoint(x: bubbleRect.maxX - cornerRadius, y: max(bubbleRect.minY + cornerRadius, midY - halfTail))
                let baseBot = CGPoint(x: bubbleRect.maxX - cornerRadius, y: min(bubbleRect.maxY - cornerRadius, midY + halfTail))
                let tip     = CGPoint(x: bubbleRect.maxX + tailLength, y: midY)
                path.move(to: baseTop)
                path.addLine(to: tip)
                path.addLine(to: baseBot)
                path.closeSubpath()
                
            case .top:
                let midX = bubbleRect.midX + tailOffset
                let baseLeft = CGPoint(x: max(bubbleRect.minX + cornerRadius, midX - halfTail), y: bubbleRect.minY + cornerRadius)
                let baseRight = CGPoint(x: min(bubbleRect.maxX - cornerRadius, midX + halfTail), y: bubbleRect.minY + cornerRadius)
                let tip       = CGPoint(x: midX, y: bubbleRect.minY - tailLength)
                path.move(to: baseLeft)
                path.addLine(to: tip)
                path.addLine(to: baseRight)
                path.closeSubpath()
                
            case .bottom:
                let midX = bubbleRect.midX + tailOffset
                let baseLeft = CGPoint(x: max(bubbleRect.minX + cornerRadius, midX - halfTail), y: bubbleRect.maxY - cornerRadius)
                let baseRight = CGPoint(x: min(bubbleRect.maxX - cornerRadius, midX + halfTail), y: bubbleRect.maxY - cornerRadius)
                let tip       = CGPoint(x: midX, y: bubbleRect.maxY + tailLength)
                path.move(to: baseLeft)
                path.addLine(to: tip)
                path.addLine(to: baseRight)
                path.closeSubpath()
        }
        
        return path
    }
}
