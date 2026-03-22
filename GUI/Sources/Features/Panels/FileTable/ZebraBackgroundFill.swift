// ZebraBackgroundFill.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 15.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Minimal zebra fill that doesn't create scroll overflow.
//              Only renders visible rows, no GeometryReader inside ScrollView.

import SwiftUI

// MARK: - Zebra Background Fill
/// Minimal zebra fill — renders just a few rows to handle edge cases.
/// Does NOT use GeometryReader (causes issues inside ScrollView).
struct ZebraBackgroundFill: View {
    let startIndex: Int
    let isActivePanel: Bool
    let rowHeight: CGFloat

    var body: some View {
        ZStack(alignment: .top) {
            stripesLayer()
                .frame(maxWidth: .infinity, alignment: .top)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: - Layers

    private func stripesLayer() -> some View {
        VStack(spacing: 0) {
            ForEach(0..<maxVisibleRows(), id: \.self) { i in
                stripeRow(index: i)
            }
        }
    }


    // MARK: - Stripe Rows

    private func stripeRow(index: Int) -> some View {
        Rectangle()
            .fill(colorForRow(index: index))
            .frame(height: rowHeight)
            .frame(maxWidth: .infinity)
    }

    private func colorForRow(index: Int) -> Color {
        let isOdd = (startIndex + index) % 2 == 1
        return stripeColor(isOdd: isOdd)
    }

    private func stripeColor(isOdd: Bool) -> Color {
        if isActivePanel {
            return isOdd ? DesignTokens.zebraActiveOdd : DesignTokens.zebraActiveEven
        } else {
            return isOdd ? DesignTokens.zebraInactiveOdd : DesignTokens.zebraInactiveEven
        }
    }


    // MARK: - Layout Calculation
    private func maxVisibleRows() -> Int {
        // Large enough to visually cover any panel height without scroll issues
        // Avoid GeometryReader completely
        return 200
    }


}
