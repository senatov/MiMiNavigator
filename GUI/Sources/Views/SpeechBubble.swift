//
//  SpeechBubble.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 30.10.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import AppKit
import SwiftUI

// MARK: - Comic speech bubble shape
struct SpeechBubble: Shape {
    var tailSize: CGSize
    var cornerRadius: CGFloat
    var tailOffset: CGPoint

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let bubbleRect = rect.insetBy(dx: 1, dy: 1)
        let r = min(cornerRadius, min(bubbleRect.width, bubbleRect.height) / 2)
        path.addRoundedRect(in: bubbleRect, cornerSize: CGSize(width: r, height: r))
        let tailBaseX = bubbleRect.minX + max(6, 12 + tailOffset.x)
        let tailBaseY = bubbleRect.maxY - max(6, 10 + tailOffset.y)
        let tailTip = CGPoint(x: tailBaseX - tailSize.width, y: tailBaseY + tailSize.height * 0.2)
        let baseLeft = CGPoint(x: tailBaseX + tailSize.width * 0.2, y: tailBaseY - tailSize.height * 0.2)
        let baseRight = CGPoint(x: tailBaseX + tailSize.width * 0.8, y: tailBaseY + tailSize.height * 0.6)

        path.move(to: baseLeft)
        path.addLine(to: tailTip)
        path.addLine(to: baseRight)
        path.closeSubpath()
        return path
    }
}
