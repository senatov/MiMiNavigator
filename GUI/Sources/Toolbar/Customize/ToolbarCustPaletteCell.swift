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
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isVisible ? Color.accentColor.opacity(0.12) : Color.gray.opacity(0.06))
                        .frame(width: 46, height: 38)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(
                                    isVisible ? Color.accentColor.opacity(0.3) : Color.gray.opacity(0.15),
                                    lineWidth: 0.8
                                )
                        )
                    Image(systemName: item.systemImage)
                        .font(.system(size: 17, weight: .medium))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(isVisible ? Color.accentColor : Color.secondary.opacity(0.45))
                        .frame(width: 46, height: 38)
                    Image(systemName: isVisible ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 11))
                        .foregroundStyle(isVisible ? Color.accentColor : Color.secondary.opacity(0.4))
                        .offset(x: 5, y: -5)
                }
                Text(item.label)
                    .font(.system(size: 10, weight: isVisible ? .medium : .regular))
                    .foregroundStyle(isVisible ? Color.primary : Color.secondary.opacity(0.6))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: 72)
            }
        }
        .buttonStyle(.plain)
        .opacity(isVisible ? 1.0 : 0.6)
        .help(item.helpText)
        .animation(.easeInOut(duration: 0.15), value: isVisible)
    }
}
