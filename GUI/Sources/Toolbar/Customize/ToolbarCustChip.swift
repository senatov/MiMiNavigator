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
                .font(.system(size: 18, weight: .regular))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.primary)
                .frame(width: 42, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.regularMaterial)
                )
            Text(item.label)
                .font(.system(size: 10))
                .foregroundStyle(.primary.opacity(0.92))
                .lineLimit(1)
                .multilineTextAlignment(.center)
                .frame(width: 74)
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 3)
        .opacity(isDragging ? 0.35 : 1.0)
        .help(item.helpText)
    }
}
