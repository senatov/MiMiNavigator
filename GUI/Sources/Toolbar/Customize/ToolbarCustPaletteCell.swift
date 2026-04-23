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
            VStack(spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isVisible ? DialogColors.accent.opacity(0.12) : Color.white.opacity(0.24))
                        .frame(width: 50, height: 40)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(
                                    isVisible ? DialogColors.accent.opacity(0.30) : DialogColors.border.opacity(0.22),
                                    lineWidth: 0.8
                                )
                        )
                    Image(systemName: item.systemImage)
                        .font(.system(size: 17, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(isVisible ? DialogColors.accent : Color.secondary.opacity(0.55))
                        .frame(width: 50, height: 40)
                    Text(isVisible ? "Shown" : "Hidden")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(isVisible ? Color.white : Color.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            Capsule(style: .continuous)
                                .fill(isVisible ? DialogColors.accent : DialogColors.border.opacity(0.22))
                        )
                        .offset(x: 10, y: -6)
                }
                Text(item.label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(isVisible ? Color.primary : Color.secondary.opacity(0.78))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: 84)
            }
            .frame(maxWidth: .infinity, minHeight: 106)
            .padding(.horizontal, 8)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(isVisible ? 0.36 : 0.18))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(DialogColors.border.opacity(isVisible ? 0.42 : 0.24), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .opacity(isVisible ? 1.0 : 0.82)
        .help(item.helpText)
        .animation(.easeInOut(duration: 0.15), value: isVisible)
    }
}
