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
        isActive ? .white : (isHovering ? .primary.opacity(0.78) : .secondary.opacity(0.55))
    }

    private var buttonFill: Color {
        isActive ? Color.blue.opacity(0.88) : Color.white.opacity(isHovering ? 0.22 : 0.10)
    }

    var body: some View {
        Image(systemName: arrowName)
            .font(.system(size: isActive ? 8 : 7, weight: .semibold))
            .foregroundStyle(arrowColor)
            .frame(width: 16, height: 16)
            .background {
                Circle()
                    .fill(buttonFill)
                    .shadow(color: .white.opacity(isActive ? 0.20 : 0.42), radius: 0.35, y: -0.5)
                    .shadow(color: .black.opacity(isActive ? 0.16 : 0.08), radius: 0.6, y: 0.5)
            }
            .overlay {
                Circle().strokeBorder(isActive ? Color.blue.opacity(0.70) : .primary.opacity(0.10), lineWidth: 0.5)
            }
            .contentShape(Circle())
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.1)) { isHovering = hovering }
                if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }
            .highPriorityGesture(TapGesture().onEnded { onSort?() })
    }
}
