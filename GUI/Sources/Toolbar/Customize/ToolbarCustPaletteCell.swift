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
            VStack(spacing: 5) {
                Image(systemName: item.systemImage)
                    .font(.system(size: 19, weight: .regular))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isVisible ? Color.primary : Color.secondary)
                    .frame(width: 42, height: 38)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
                    .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color.primary.opacity(0.12)))
                Text(item.label)
                    .font(.system(size: 10))
                    .foregroundStyle(isVisible ? Color.primary : Color.secondary.opacity(0.8))
                    .lineLimit(1)
            }
            .frame(width: 100, height: 62)
        }
        .buttonStyle(.plain)
        .opacity(isVisible ? 0.58 : 1.0)
        .help(item.helpText)
        .animation(.easeInOut(duration: 0.15), value: isVisible)
    }
}
