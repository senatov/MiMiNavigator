// ToolbarCustPaletteCell.swift
// MiMiNavigator
//
// Created by Claude on 24.04.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Grid cell in "Available Items" palette. Click toggles visibility.

import SwiftUI

// MARK: - Palette Cell
struct ToolbarCustPaletteCell: View {
    let item: ToolbarItemID
    let isVisible: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 9) {
                Image(systemName: item.systemImage)
                    .font(.system(size: 14, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isVisible ? DialogColors.accent : Color.secondary)
                    .frame(width: 26, height: 26)
                    .background(DialogColors.accent.opacity(isVisible ? 0.10 : 0), in: RoundedRectangle(cornerRadius: 6))
                Text(item.label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isVisible ? Color.primary : Color.secondary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Image(systemName: isVisible ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 13))
                    .foregroundStyle(isVisible ? DialogColors.accent : Color.secondary.opacity(0.5))
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(isVisible ? 0.62 : 0.28))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(DialogColors.border.opacity(isVisible ? 0.48 : 0.28), lineWidth: 0.75)
            )
        }
        .buttonStyle(.plain)
        .opacity(isVisible ? 1.0 : 0.72)
        .help(item.helpText)
        .animation(.easeInOut(duration: 0.15), value: isVisible)
    }
}
