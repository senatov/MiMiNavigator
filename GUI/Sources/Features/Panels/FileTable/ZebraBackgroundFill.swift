// ZebraBackgroundFill.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 15.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Draws zebra-striped background to fill empty panel space below file rows.

import SwiftUI

// MARK: - Zebra Background Fill
/// Renders repeating zebra stripes to fill empty space below file rows.
/// Continues the alternating pattern from the last file row index.
/// Uses a simple VStack of colored rectangles for reliable rendering inside LazyVStack.
struct ZebraBackgroundFill: View {
    let startIndex: Int
    let isActivePanel: Bool
    let rowHeight: CGFloat

    private var stripeCount: Int { 40 }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<stripeCount, id: \.self) { i in
                let isOdd = (startIndex + i) % 2 == 1
                Rectangle()
                    .fill(stripeColor(isOdd: isOdd))
                    .frame(height: rowHeight)
                    .frame(maxWidth: .infinity)
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
