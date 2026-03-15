// SortArrowButton.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 27.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Clickable sort indicator — macOS HIG style (Finder-like triangle).
//              Shows small triangle when sorted, subtle indicator when not.

import AppKit
import SwiftUI

// MARK: - SortArrowButton
/// Clickable sort indicator — macOS HIG style (Finder-like triangle).
/// Shows small triangle when sorted, subtle indicator when not.
struct SortArrowButton: View {
    let isActive: Bool
    let ascending: Bool
    let onSort: (() -> Void)?

    @State private var isHovering = false

    private var arrowName: String {
        if isActive {
            return ascending ? "chevron.up" : "chevron.down"
        } else {
            return "chevron.up.chevron.down"
        }
    }

    private var arrowColor: Color {
        if isHovering {
            return Color.primary
        }
        guard isActive else {
            return Color.secondary.opacity(0.5)
        }
        return Color.accentColor
    }

    var body: some View {
        Image(systemName: arrowName)
            .font(.system(size: isActive ? 12 : 11, weight: isActive ? .bold : .medium))
            .foregroundStyle(arrowColor)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .contentShape(Rectangle().inset(by: -4))
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.1)) {
                    isHovering = hovering
                }
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
            .onTapGesture {
                onSort?()
            }
    }
}
