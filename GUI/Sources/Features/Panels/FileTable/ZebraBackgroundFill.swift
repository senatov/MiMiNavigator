// ZebraBackgroundFill.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 15.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Zebra fill for the empty area below file rows.

import SwiftUI

// MARK: - Zebra Background Fill
struct ZebraBackgroundFill: View {
    private static let stripeCount = 200
    let startIndex: Int
    let isActivePanel: Bool
    let rowHeight: CGFloat

    var body: some View {
        ZStack(alignment: .top) {
            stripesLayer
                .frame(maxWidth: .infinity, alignment: .top)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var stripesLayer: some View {
        VStack(spacing: 0) {
            ForEach(0..<Self.stripeCount, id: \.self) { i in
                stripeRow(index: i)
            }
        }
    }

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


}
