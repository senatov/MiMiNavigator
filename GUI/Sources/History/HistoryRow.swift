// HistoryRow.swift
// MiMiNavigator
//
// Extracted from HistoryPopoverView.swift on 13.02.2026
// Updated: 14.02.2026 — search highlight support
// Copyright © 2025-2026 Senatov. All rights reserved.
// Description: Single row in navigation history list with optional text highlight

import SwiftUI

// MARK: - History Row
struct HistoryRow: View {
    let path: String
    var highlightText: String = ""
    let onSelect: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    // MARK: - Computed Properties

    private var displayName: String {
        URL(fileURLWithPath: path).lastPathComponent
    }

    private var parentPath: String {
        let parent = URL(fileURLWithPath: path).deletingLastPathComponent().path
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return parent.hasPrefix(home) ? "~" + parent.dropFirst(home.count) : parent
    }

    private var iconName: String {
        let p = path.lowercased()
        if p.hasPrefix("/volumes/") { return "externaldrive.fill" }
        if p.contains("/applications") { return "square.grid.3x3.fill" }
        if p.contains("/library") { return "building.columns.fill" }
        if p.contains("/desktop") { return "desktopcomputer" }
        if p.contains("/documents") { return "doc.text.fill" }
        if p.contains("/downloads") { return "arrow.down.circle.fill" }
        if p.contains("/movies") { return "film.fill" }
        if p.contains("/music") { return "music.note" }
        if p.contains("/pictures") { return "photo.fill" }
        return "folder.fill"
    }

    private var iconColor: Color {
        let p = path.lowercased()
        if p.hasPrefix("/volumes/") { return .purple }
        if p.contains("/applications") { return .green }
        if p.contains("/library") || p.contains("/system") { return .red }
        if p.contains("/users") { return .orange }
        return .blue.opacity(0.8)
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .font(.system(size: 14))
                .foregroundStyle(iconColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 1) {
                highlightedText(displayName)
                    .font(.system(size: 12, weight: isHovered ? .medium : .regular))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                highlightedText(parentPath)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.head)
            }

            Spacer(minLength: 4)

            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(isHovered ? .red.opacity(0.8) : .secondary.opacity(0.5))
            }
            .buttonStyle(.plain)
            .opacity(isHovered ? 1 : 0.6)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(isHovered ? Color.accentColor.opacity(0.1) : .clear)
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture(perform: onSelect)
        .help(path)
    }

    // MARK: - Highlighted Text

    @ViewBuilder
    private func highlightedText(_ text: String) -> some View {
        if highlightText.isEmpty {
            Text(text)
        } else {
            Text(buildHighlightedAttributedString(text, highlight: highlightText))
        }
    }

    private func buildHighlightedAttributedString(_ text: String, highlight: String) -> AttributedString {
        var attributed = AttributedString(text)
        let lowerText = text.lowercased()
        let lowerHighlight = highlight.lowercased()

        var searchStart = lowerText.startIndex
        while let range = lowerText.range(of: lowerHighlight, range: searchStart..<lowerText.endIndex) {
            let attrStart = AttributedString.Index(range.lowerBound, within: attributed)
            let attrEnd = AttributedString.Index(range.upperBound, within: attributed)
            if let start = attrStart, let end = attrEnd {
                attributed[start..<end].backgroundColor = .yellow.opacity(0.4)
                attributed[start..<end].font = .system(size: 12, weight: .bold)
            }
            searchStart = range.upperBound
        }
        return attributed
    }
}
