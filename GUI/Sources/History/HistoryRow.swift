// HistoryRow.swift
// MiMiNavigator
//
// Extracted from HistoryPopoverView.swift on 13.02.2026
// Copyright © 2025-2026 Senatov. All rights reserved.
// Description: Single row in navigation history list

import SwiftUI

// MARK: - History Row
/// Displays a single history entry with icon, path info, and delete button.
struct HistoryRow: View {
    let path: String
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
                Text(displayName)
                    .font(.system(size: 12, weight: isHovered ? .medium : .regular))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                Text(parentPath)
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
}
