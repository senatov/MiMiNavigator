// TopDropdownLabel.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Shared flat label for top-menu dropdown controls.

import AppKit
import SwiftUI

// MARK: - Top Dropdown Label
struct TopDropdownLabel: View {
    let title: String
    let systemImage: String
    let tint: Color

    // MARK: - Body
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .light))
                .foregroundStyle(tint)
            Text(title)
                .font(.system(size: 14, weight: .light))
                .foregroundStyle(Color.primary.opacity(0.92))
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
    }
}
