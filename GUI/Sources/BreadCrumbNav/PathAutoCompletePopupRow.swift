// PathAutoCompletePopupRow.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Interactive autocomplete row with recent-directory styling.

import SwiftUI

// MARK: - Auto Complete Popup Row
struct AutoCompletePopupRow: View {
    let item: AutoCompleteItem
    let isSelected: Bool
    let selectionNamespace: Namespace.ID
    let onAccept: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            AsyncSmartIconView(file: item.file)
                .frame(width: 18, height: 18)
                .allowsHitTesting(false)
            highlightedName
                .foregroundStyle(item.isRecent ? Color.primary.opacity(0.82) : Color.primary)
            Spacer(minLength: 8)
            if item.isRecent {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .help(L10n.PathInput.recentlyVisited)
            }
            if isSelected {
                Text("↩")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.tertiary)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 34)
        .contentShape(.rect)
        .background(rowBackground)
        .onHover { isHovered = $0 }
        .onTapGesture(perform: onAccept)
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var rowBackground: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.accentColor.opacity(0.16))
                .matchedGeometryEffect(id: "selection", in: selectionNamespace)
        } else if isHovered {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.primary.opacity(0.055))
        } else if item.isRecent {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.primary.opacity(0.035))
        }
    }

    private var highlightedName: some View {
        HStack(spacing: 0) {
            Text(matchedPrefix)
                .fontWeight(.semibold)
            Text(unmatchedSuffix)
        }
        .font(.system(size: 13, weight: item.isRecent ? .medium : .regular))
        .lineLimit(1)
        .truncationMode(.middle)
    }

    private var matchedPrefix: String {
        guard !item.matchPrefix.isEmpty,
              item.name.range(of: item.matchPrefix, options: [.caseInsensitive, .anchored]) != nil
        else { return "" }
        return String(item.name.prefix(item.matchPrefix.count))
    }

    private var unmatchedSuffix: String {
        String(item.name.dropFirst(matchedPrefix.count))
    }
}
