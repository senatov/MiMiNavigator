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
        VStack(spacing: 6) {
            Image(systemName: item.systemImage)
                .font(.system(size: 16, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(DialogColors.accent)
                .frame(width: 40, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(DialogColors.accent.opacity(isInToolbar ? 0.12 : 0.08))
                )
            Text(item.label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.primary.opacity(0.92))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 74)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(isDragging ? 0.14 : 0.32))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(DialogColors.border.opacity(isDragging ? 0.28 : 0.42), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(isDragging ? 0.03 : 0.06), radius: 6, y: 2)
        .opacity(isDragging ? 0.35 : 1.0)
        .help(item.helpText)
    }
}
