// HistoryRow.swift
// MiMiNavigator
//
// Extracted from HistoryPopoverView.swift on 13.02.2026
// Updated: 14.03.2026 — macOS 26 HIG: no custom row borders, system list handles chrome
// Copyright © 2025-2026 Senatov. All rights reserved.
// Description: Single row in navigation history List with hover, highlight, swipe-delete.

import SwiftUI

// MARK: - History Row
struct HistoryRow: View {
    let path: String
    var highlightText: String = ""
    let onSelect: () -> Void
    let onDelete: () -> Void
    @State private var isHovered = false
    // MARK: - Computed Properties
    private var displayName: String { URL(fileURLWithPath: path).lastPathComponent }
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
        return .accentColor
    }
    // MARK: - Body
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .font(.system(size: 14))
                .foregroundStyle(iconColor)
                .frame(width: 20, alignment: .center)
            VStack(alignment: .leading, spacing: 1) {
                highlightedText(displayName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                highlightedText(parentPath)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 4)
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.red.opacity(0.7))
            }
            .buttonStyle(.plain)
            .opacity(isHovered ? 1 : 0)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture(perform: onSelect)
        .help(path)
    }
    // MARK: - Highlighted Text
    @ViewBuilder
    private func highlightedText(_ text: String) -> some View {
        if highlightText.isEmpty {
            Text(text)
        } else {
            Text(buildHighlighted(text, highlight: highlightText))
        }
    }
    // MARK: - Build Highlighted Attributed String
    private func buildHighlighted(_ text: String, highlight: String) -> AttributedString {
        var attributed = AttributedString(text)
        let lowerText = text.lowercased()
        let lowerHL = highlight.lowercased()
        var pos = lowerText.startIndex
        while let range = lowerText.range(of: lowerHL, range: pos..<lowerText.endIndex) {
            if let s = AttributedString.Index(range.lowerBound, within: attributed),
               let e = AttributedString.Index(range.upperBound, within: attributed) {
                attributed[s..<e].backgroundColor = .yellow.opacity(0.35)
                attributed[s..<e].font = .system(size: 12, weight: .bold)
            }
            pos = range.upperBound
        }
        return attributed
    }
}
