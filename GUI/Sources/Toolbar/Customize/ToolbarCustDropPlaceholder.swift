// ToolbarCustDropPlaceholder.swift
// MiMiNavigator
//
// Created by Claude on 24.04.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Dashed drop placeholder at the end of Current Toolbar strip.

import SwiftUI

// MARK: - Drop Placeholder
struct ToolbarCustDropPlaceholder: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .strokeBorder(
                Color.accentColor.opacity(0.45),
                style: StrokeStyle(lineWidth: 1.5, dash: [5, 3])
            )
            .frame(width: 38, height: 30)
            .overlay(
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.accentColor.opacity(0.5))
            )
    }
}
