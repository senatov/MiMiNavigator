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

    // Only render 2 extra rows max — enough to fill typical gaps without overflow
    private var stripeCount: Int { 2 }

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

    private func stripeColor(isOdd: Bool) -> Color {
        if isActivePanel {
            return isOdd ? DesignTokens.zebraActiveOdd : DesignTokens.zebraActiveEven
        } else {
            return isOdd ? DesignTokens.zebraInactiveOdd : DesignTokens.zebraInactiveEven
        }
    }
}
