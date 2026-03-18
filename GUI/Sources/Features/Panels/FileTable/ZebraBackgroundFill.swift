// ZebraBackgroundFill.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 15.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Draws zebra-striped background to fill remaining panel space below file rows.
//              Uses GeometryReader to fill only visible viewport — no extra scrollable content.

import SwiftUI

// MARK: - Zebra Background Fill
/// Renders zebra stripes to fill empty space below file rows.
/// Uses GeometryReader to measure available space and fill exactly that — no overflow.
struct ZebraBackgroundFill: View {
    let startIndex: Int
    let isActivePanel: Bool
    let rowHeight: CGFloat

    var body: some View {
        GeometryReader { geo in
            let availableHeight = geo.size.height
            let stripeCount = max(0, Int(ceil(availableHeight / rowHeight)))
            
            VStack(spacing: 0) {
                ForEach(0..<stripeCount, id: \.self) { i in
                    let isOdd = (startIndex + i) % 2 == 1
                    Rectangle()
                        .fill(stripeColor(isOdd: isOdd))
                        .frame(height: rowHeight)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Stripe Color
    private func stripeColor(isOdd: Bool) -> Color {
        if isActivePanel {
            return isOdd ? DesignTokens.zebraActiveOdd : DesignTokens.zebraActiveEven
        } else {
            return isOdd ? DesignTokens.zebraInactiveOdd : DesignTokens.zebraInactiveEven
        }
    }
}
