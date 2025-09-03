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
                    .fill(FilePanelStyle.orangeSelectedRowStroke) // less intense pale yellow background
                    .shadow(color: .secondary.opacity(0.40), radius: 7.0, x: 1, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(FilePanelStyle.dirNameColor, lineWidth: 0.6) // light border
            )
            .foregroundColor(.black)
    }
}
