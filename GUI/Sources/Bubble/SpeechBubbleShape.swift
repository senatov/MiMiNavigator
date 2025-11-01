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

    /// Speech bubble with configurable tail direction and offset along the edge.
public struct SpeechBubbleShape: Shape {
    
    public enum Direction: Sendable {
        case up, down, left, right
    }
    
    public var cornerRadius: CGFloat
    public var tailLength: CGFloat
    public var tailWidth: CGFloat
    public var tailDirection: Direction
        /// Offset of the tail anchor along the edge where the tail sits.
        /// For horizontal edges (up/down): measured from the left corner.
        /// For vertical edges (left/right): measured from the top corner.
    public var tailOffset: CGFloat
    
        // Animate tail offset smoothly
    public var animatableData: CGFloat {
        get { tailOffset }
        set { tailOffset = newValue }
    }
    
    public init(
        cornerRadius: CGFloat = 12,
        tailLength: CGFloat = 12,
        tailWidth: CGFloat = 18,
        tailDirection: Direction = .up,
        tailOffset: CGFloat = 40
    ) {
        self.cornerRadius = cornerRadius
        self.tailLength = tailLength
        self.tailWidth = tailWidth
        self.tailDirection = tailDirection
        self.tailOffset = tailOffset
    }
    
    public func path(in rect: CGRect) -> Path {
            // Reserve space for the tail
            // Body is the rounded rectangle area excluding the tail protrusion.
        let body: CGRect
        switch tailDirection {
            case .up:
                    // Reserve space on top for the tail
                body = CGRect(
                    x: rect.minX,
                    y: rect.minY + tailLength,
                    width: rect.width,
                    height: rect.height - tailLength
                )
            case .down:
                    // Reserve space at bottom for the tail
                body = CGRect(
                    x: rect.minX,
                    y: rect.minY,
                    width: rect.width,
                    height: rect.height - tailLength
                )
            case .left:
                    // Reserve space at left for the tail
                body = CGRect(
                    x: rect.minX + tailLength,
                    y: rect.minY,
                    width: rect.width - tailLength,
                    height: rect.height
                )
            case .right:
                    // Reserve space at right for the tail
                body = CGRect(
                    x: rect.minX,
                    y: rect.minY,
                    width: rect.width - tailLength,
                    height: rect.height
                )
        }
        
        let r = min(cornerRadius, min(body.width, body.height) * 0.5)
        
            // Compute tail base center along the chosen edge and clamp to stay inside rounded corners.
        let halfBase = tailWidth * 0.5
        
            // Helpers to clamp along top/bottom (horizontal) or left/right (vertical) edges
        func clampedX(for raw: CGFloat) -> CGFloat {
            let minX = body.minX + r + halfBase
            let maxX = body.maxX - r - halfBase
            return max(minX, min(maxX, raw))
        }
        func clampedY(for raw: CGFloat) -> CGFloat {
            let minY = body.minY + r + halfBase
            let maxY = body.maxY - r - halfBase
            return max(minY, min(maxY, raw))
        }
        
            // Tail base center point on the body edge
        let baseCenter: CGPoint
        switch tailDirection {
            case .up:
                baseCenter = CGPoint(x: clampedX(for: body.minX + tailOffset), y: body.minY)
            case .down:
                baseCenter = CGPoint(x: clampedX(for: body.minX + tailOffset), y: body.maxY)
            case .left:
                baseCenter = CGPoint(x: body.minX, y: clampedY(for: body.minY + tailOffset))
            case .right:
                baseCenter = CGPoint(x: body.maxX, y: clampedY(for: body.minY + tailOffset))
        }
        
        var p = Path()
        
            // Start at top-left rounded corner start
        p.move(to: CGPoint(x: body.minX + r, y: body.minY))
        
            // TOP EDGE (left → right), insert tail if needed
        if tailDirection == .up {
                // to left base
            p.addLine(to: CGPoint(x: baseCenter.x - halfBase, y: body.minY))
                // tail tip
            p.addLine(to: CGPoint(x: baseCenter.x, y: rect.minY))
                // to right base
            p.addLine(to: CGPoint(x: baseCenter.x + halfBase, y: body.minY))
        }
            // continue to top-right corner
        p.addLine(to: CGPoint(x: body.maxX - r, y: body.minY))
        p.addQuadCurve(to: CGPoint(x: body.maxX, y: body.minY + r),
                       control: CGPoint(x: body.maxX, y: body.minY))
        
            // RIGHT EDGE (top → bottom)
        if tailDirection == .right {
            p.addLine(to: CGPoint(x: body.maxX, y: baseCenter.y - halfBase))
            p.addLine(to: CGPoint(x: rect.maxX, y: baseCenter.y))
            p.addLine(to: CGPoint(x: body.maxX, y: baseCenter.y + halfBase))
        }
        p.addLine(to: CGPoint(x: body.maxX, y: body.maxY - r))
        p.addQuadCurve(to: CGPoint(x: body.maxX - r, y: body.maxY),
                       control: CGPoint(x: body.maxX, y: body.maxY))
        
            // BOTTOM EDGE (right → left)
        if tailDirection == .down {
            p.addLine(to: CGPoint(x: baseCenter.x + halfBase, y: body.maxY))
            p.addLine(to: CGPoint(x: baseCenter.x, y: rect.maxY))
            p.addLine(to: CGPoint(x: baseCenter.x - halfBase, y: body.maxY))
        }
        p.addLine(to: CGPoint(x: body.minX + r, y: body.maxY))
        p.addQuadCurve(to: CGPoint(x: body.minX, y: body.maxY - r),
                       control: CGPoint(x: body.minX, y: body.maxY))
        
            // LEFT EDGE (bottom → top)
        if tailDirection == .left {
            p.addLine(to: CGPoint(x: body.minX, y: baseCenter.y + halfBase))
            p.addLine(to: CGPoint(x: rect.minX, y: baseCenter.y))
            p.addLine(to: CGPoint(x: body.minX, y: baseCenter.y - halfBase))
        }
        p.addLine(to: CGPoint(x: body.minX, y: body.minY + r))
        p.addQuadCurve(to: CGPoint(x: body.minX + r, y: body.minY),
                       control: CGPoint(x: body.minX, y: body.minY))
        
        p.closeSubpath()
        return p
    }
}
