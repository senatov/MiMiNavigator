// TopDropdownLabel.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Shared flat label for top-menu dropdown controls.

import AppKit
import SwiftUI

// MARK: - Top Menu Icon
struct TopMenuIcon: View {
    let systemImage: String
    let tint: Color

    // MARK: - Body
    var body: some View {
        Image(nsImage: coloredSymbol)
            .renderingMode(.original)
            .frame(width: 15, height: 15)
    }

    private var coloredSymbol: NSImage {
        let configuration = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
            .applying(NSImage.SymbolConfiguration(paletteColors: [NSColor(tint)]))
        let image = NSImage(systemSymbolName: systemImage, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration) ?? NSImage(size: NSSize(width: 15, height: 15))
        image.isTemplate = false
        return image
    }
}

// MARK: - Top Dropdown Label
struct TopDropdownLabel: View {
    let title: String
    let systemImage: String
    let tint: Color

    // MARK: - Body
    var body: some View {
        HStack(spacing: 5) {
            TopMenuIcon(systemImage: systemImage, tint: tint)
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
            .padding(.vertical, 2)
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
