// UserFavoriteRow.swift
// FavoritesKit
//
// Created by Iakov Senatov on 22.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Single row for user-added favorites in FavoritesTreeView.
//              Shows icon + name + small remove button on hover.

import SwiftUI

// MARK: - UserFavoriteRow
struct UserFavoriteRow: View {

    let entry: UserFavoriteEntry
    let onNavigate: (String) -> Void
    let onRemove: () -> Void

    @State private var isHovered = false

    // MARK: -
    var body: some View {
        HStack(spacing: 6) {
            // Indent spacer (align with system favorites rows)
            Color.clear.frame(width: 14)

            // Icon
            Image(systemName: entry.displayIcon)
                .font(.system(size: 13))
                .foregroundStyle(entry.isNetworkShare ? .blue : .blue.opacity(0.8))
                .symbolRenderingMode(.hierarchical)
                .frame(width: 18, height: 18)

            // Name + path tooltip
            Text(entry.name)
                .font(.system(size: 12))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.middle)
                .help(entry.path)

            Spacer(minLength: 4)

            // Remove button — visible only on hover
            if isHovered {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Remove from Favorites")
                .transition(.opacity.combined(with: .scale(scale: 0.7)))
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(isHovered ? Color.primary.opacity(0.05) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture(count: 2) { onNavigate(entry.path) }
        .onTapGesture { /* single tap = no-op, double = navigate */ }
        .animation(.easeInOut(duration: 0.12), value: isHovered)
    }
}
