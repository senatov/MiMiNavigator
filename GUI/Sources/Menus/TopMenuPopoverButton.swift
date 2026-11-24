// TopMenuPopoverButton.swift
// MiMiNavigator
// Copyright © 2026 Senatov. All rights reserved.

import SwiftUI

// MARK: - Top Menu Popover Button
struct TopMenuPopoverButton: View {
    let menu: MenuCategory
    let tint: Color
    @State private var isPresented = false

    // MARK: - Body
    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            TopDropdownLabel(title: menu.title, systemImage: menu.icon ?? "ellipsis", tint: tint)
        }
        .buttonStyle(.plain)
        .controlSize(.small)
        .help("Open menu: \(menu.title)")
        .keyboardFocusable()
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 3) {
                Text(menu.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                ForEach(menu.items) { item in
                    TopMenuPopoverRow(item: item, tint: tint) {
                        isPresented = false
                        item.action()
                    }
                }
            }
            .padding(8)
            .frame(minWidth: 270)
        }
    }
}

// MARK: - Top Menu Popover Row
private struct TopMenuPopoverRow: View {
    let item: MenuItem
    let tint: Color
    let action: () -> Void
    @State private var isHovered = false

    // MARK: - Body
    var body: some View {
        let enabled = item.isEnabled()
        let selected = item.isSelected?() ?? false
        return Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: item.icon ?? "circle")
                    .foregroundStyle(tint)
                    .frame(width: 18)
                    .accessibilityHidden(true)
                Text(item.title)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let shortcut = item.shortcut, !shortcut.isEmpty {
                    Text(shortcut)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if item.isSelected != nil {
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selected ? tint : Color.secondary)
                        .frame(width: 18)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
            .background {
                if isHovered && enabled {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.primary.opacity(0.10))
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .onHover { isHovered = $0 }
        .accessibilityValue(item.isSelected == nil ? "" : (selected ? "On" : "Off"))
    }
}
