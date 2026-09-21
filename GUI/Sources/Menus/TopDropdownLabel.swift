// TopDropdownLabel.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Shared flat label for top-menu dropdown controls.

import AppKit
import SwiftUI

// MARK: - Top Dropdown Label
struct TopDropdownLabel: View {
    let title: String
    let systemImage: String
    let tint: Color

    // MARK: - Body
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(tint)
            Text(title)
                .font(.callout)
                .foregroundStyle(Color.primary.opacity(0.92))
                .lineLimit(1)
        }
        .topDropdownLabelSurface()
    }
}

// MARK: - Top Dropdown Label Surface
private struct TopDropdownLabelSurface: ViewModifier {
    @State private var isHovered = false
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background {
                if isHovered {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.primary.opacity(0.10))
                }
            }
            .overlay {
                if isHovered {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.16), lineWidth: 0.6)
                }
            }
            .onHover { isHovered = $0 }
            .animation(.easeOut(duration: 0.12), value: isHovered)
    }
}

// MARK: - Top Dropdown Label Surface Extension
extension View {
    func topDropdownLabelSurface() -> some View {
        modifier(TopDropdownLabelSurface())
    }
}
