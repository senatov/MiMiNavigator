//
//  PrettyTooltip.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 26.03.25.
//  Copyright © 2025 Senatov. All rights reserved.
//
import SwiftUI

struct PrettyTooltip: View {
    let text: String

    // MARK: - Tooltip for divider
    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .regular, design: .default))
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color(#colorLiteral(red: 0.9529411793, green: 0.6862745285, blue: 0.1333333403, alpha: 1))) // less intense pale yellow background
                    .shadow(color: .secondary.opacity(0.40), radius: 7.0, x: 1, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(Color(#colorLiteral(red: 0.1019607857, green: 0.2784313858, blue: 0.400000006, alpha: 1)), lineWidth: 0.4) // light border
            )
            .foregroundColor(.black)
    }
}
