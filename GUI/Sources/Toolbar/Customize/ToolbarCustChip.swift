// ToolbarCustChip.swift
// MiMiNavigator
//
// Created by Claude on 24.04.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Draggable chip representing a toolbar button in the "Current Toolbar" strip.

import SwiftUI

// MARK: - Toolbar Customize Chip
struct ToolbarCustChip: View {
    let item: ToolbarItemID
    let isInToolbar: Bool
    let isDragging: Bool

    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: item.systemImage)
                .font(.system(size: 16, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.accentColor)
                .frame(width: 38, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.accentColor.opacity(0.10))
                )
            Text(item.label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .opacity(isDragging ? 0.35 : 1.0)
        .help(item.helpText)
    }
}
