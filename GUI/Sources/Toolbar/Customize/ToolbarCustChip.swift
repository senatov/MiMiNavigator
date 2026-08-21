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
                .font(.system(size: 13, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(DialogColors.accent)
                .frame(width: 28, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(DialogColors.accent.opacity(isInToolbar ? 0.10 : 0.06))
                )
            Text(item.label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.primary.opacity(0.92))
                .lineLimit(1)
                .multilineTextAlignment(.center)
                .frame(width: 64)
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(isDragging ? 0.18 : 0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(DialogColors.border.opacity(isDragging ? 0.3 : 0.45), lineWidth: 0.75)
        )
        .opacity(isDragging ? 0.35 : 1.0)
        .help(item.helpText)
    }
}
