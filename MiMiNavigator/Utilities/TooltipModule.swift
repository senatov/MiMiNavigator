//
//  FileName.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 16.10.24.

//  Description: This file contains the implementation of XYZ functionality.
//
import SwiftUI

/// TooltipModule is responsible for calculating the tooltip text and position.

// MARK: --
struct TooltipModule {
    static func calculateTooltip(location: CGPoint, dividerX: CGFloat, totalWidth: CGFloat) -> (String, CGPoint) {
        // Tooltip text showing the ratio between left and right panels
        let leftRatio = (dividerX / totalWidth * 100).rounded()
        let rightRatio = (100 - leftRatio).rounded()
        let tooltipText = "Left: \(leftRatio)% | Right: \(rightRatio)%"

        // Position tooltip relative to the divider with slight offset to the right and above
        let adjustedX = location.x + dividerX + 100 // Slightly to the right of the divider
        let adjustedY = location.y - 5 // Slightly above the cursor
        let tooltipPosition = CGPoint(x: adjustedX, y: adjustedY)

        return (tooltipText, tooltipPosition)
    }
}
