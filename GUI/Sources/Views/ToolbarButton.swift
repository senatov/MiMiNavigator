// ToolbarButton.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 11.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Toolbar button components — macOS 26 HIG, crisp SF Symbols.
//   Custom tooltip overlay because .help() doesn't work reliably
//   in .windowToolbarStyle(.unifiedCompact).

import SwiftUI

// MARK: - Shared icon style
private struct ToolbarIcon: View {
    let name: String
    var active: Bool = false

    var body: some View {
        Image(systemName: name)
            .symbolRenderingMode(.hierarchical)
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(active ? Color.accentColor : Color.primary)
    }
}

// MARK: - Fast Tooltip Modifier
/// Shows a tooltip popup after 0.5s hover delay.
/// Works around .help() being broken in unifiedCompact toolbar style.
private struct FastTooltip: ViewModifier {
    let text: String
    @State private var isHovering = false
    @State private var showTooltip = false
    @State private var hoverTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .onHover { hovering in
                isHovering = hovering
                if hovering {
                    hoverTask = Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(500))
                        if isHovering {
                            showTooltip = true
                        }
                    }
                } else {
                    hoverTask?.cancel()
                    hoverTask = nil
                    showTooltip = false
                }
            }
            .overlay(alignment: .bottom) {
                if showTooltip {
                    Text(text)
                        .font(.system(size: 11))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(nsColor: .windowBackgroundColor))
                                .shadow(color: .black.opacity(0.2), radius: 3, y: 2)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
                        )
                        .fixedSize()
                        .offset(y: 28)
                        .allowsHitTesting(false)
                        .transition(.opacity.animation(.easeIn(duration: 0.12)))
                        .zIndex(999)
                }
            }
    }
}

private extension View {
    func fastTooltip(_ text: String) -> some View {
        modifier(FastTooltip(text: text))
    }
}

// MARK: - Standard Toolbar Button
struct ToolbarButton: View {
    let systemImage: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ToolbarIcon(name: systemImage)
        }
        .buttonStyle(.borderless)
        .help(help)
        .fastTooltip(help)
    }
}

// MARK: - Toggle Toolbar Button
struct ToolbarToggleButton: View {
    let systemImage: String
    let activeImage: String
    let helpActive: String
    let helpInactive: String
    @Binding var isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ToolbarIcon(name: isActive ? activeImage : systemImage, active: isActive)
        }
        .buttonStyle(.borderless)
        .help(isActive ? helpActive : helpInactive)
        .fastTooltip(isActive ? helpActive : helpInactive)
    }
}
