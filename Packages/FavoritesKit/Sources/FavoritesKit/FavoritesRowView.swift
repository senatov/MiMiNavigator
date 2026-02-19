//
// FavoritesRowView.swift
// FavoritesKit
//
// Created by Iakov Senatov on 17.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
//
// Description: Single row in favorites tree with expand/collapse support.
// Uses value types instead of Bindings to avoid index out of range during async updates.

import SwiftUI

// MARK: - FavoritesRowView

struct FavoritesRowView: View {
    
    // MARK: - Properties (value types, no Bindings for item)
    
    let item: FavoriteItem
    @Binding var expandedFolders: Set<String>
    @Binding var isPresented: Bool
    
    let panelSide: FavPanelSide
    weak var navigationDelegate: FavoritesNavigationDelegate?
    
    @State private var isHovered = false
    
    // MARK: - Safe Computed Properties
    
    private var itemPath: String { item.path }
    private var itemName: String { item.name }
    private var itemId: UUID { item.id }
    
    private var isExpanded: Bool {
        expandedFolders.contains(itemPath)
    }
    
    private var isNavigable: Bool {
        item.isDirectory || item.isSymbolicDirectory
    }
    
    private var indentLevel: Int {
        guard !itemPath.isEmpty else { return 0 }
        let parts = itemPath.split(separator: "/", omittingEmptySubsequences: true)
        return max(0, parts.count - 3)
    }
    
    private var children: [FavoriteItem] {
        (item.children as? [FavoriteItem]) ?? []
    }
    
    private var hasChildren: Bool {
        !children.isEmpty
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            rowContent
            childrenSection
        }
        .task(id: itemId) {
            await autoExpandIfNeeded()
        }
    }
    
    // MARK: - Row Content
    
    private var rowContent: some View {
        HStack(spacing: 6) {
            chevronView
            iconView
            labelView
            Spacer(minLength: 4)
            badgeView
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .padding(.leading, CGFloat(indentLevel) * 16)
        .background(backgroundView)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture(count: 2, perform: navigateToItem)
        .onTapGesture(perform: toggleIfNavigable)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(itemName)
    }
    
    // MARK: - Chevron
    
    @ViewBuilder
    private var chevronView: some View {
        if isNavigable && hasChildren {
            Button(action: toggleExpansion) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 14, height: 14)
            }
            .buttonStyle(.plain)
        } else {
            Color.clear.frame(width: 14, height: 14)
        }
    }
    
    // MARK: - Icon
    
    private var iconView: some View {
        Image(systemName: iconName)
            .font(.system(size: 14))
            .foregroundStyle(iconColor)
            .symbolRenderingMode(.hierarchical)
            .frame(width: 18, height: 18)
    }
    
    // MARK: - Label
    
    private var labelView: some View {
        Text(itemName)
            .font(.system(size: 12, weight: isHovered ? .medium : .regular))
            .foregroundStyle(.primary)
            .lineLimit(1)
            .truncationMode(.middle)
            .help(itemPath.isEmpty ? itemName : itemPath)
    }
    
    // MARK: - Badge
    
    @ViewBuilder
    private var badgeView: some View {
        let count = children.count
        if count > 0 {
            Text("\(count)")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.secondary.opacity(0.12)))
        }
    }
    
    // MARK: - Background
    
    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(backgroundColor)
    }
    
    private var backgroundColor: Color {
        if isExpanded { return Color.accentColor.opacity(0.1) }
        if isHovered { return Color.primary.opacity(0.05) }
        return .clear
    }
    
    // MARK: - Children Section
    
    @ViewBuilder
    private var childrenSection: some View {
        if isExpanded && hasChildren {
            ForEach(children, id: \.id) { child in
                FavoritesRowView(
                    item: child,
                    expandedFolders: $expandedFolders,
                    isPresented: $isPresented,
                    panelSide: panelSide,
                    navigationDelegate: navigationDelegate
                )
            }
        }
    }
    
    // MARK: - Actions
    
    private func toggleExpansion() {
        withAnimation(.easeInOut(duration: 0.2)) {
            if isExpanded {
                expandedFolders.remove(itemPath)
            } else {
                expandedFolders.insert(itemPath)
            }
        }
    }
    
    private func toggleIfNavigable() {
        guard isNavigable else { return }
        toggleExpansion()
    }
    
    private func navigateToItem() {
        // If path is empty (group item), try to navigate to first child with valid path
        var targetPath = itemPath
        if targetPath.isEmpty, let firstChild = children.first {
            targetPath = firstChild.path
        }
        
        guard isNavigable, !targetPath.isEmpty else { return }
        
        Task { @MainActor in
            await navigationDelegate?.navigateToPath(targetPath, panel: panelSide)
            isPresented = false
        }
    }
    
    // MARK: - Auto Expand (disabled - start collapsed)
    @MainActor
    private func autoExpandIfNeeded() async {
        // Auto-expand disabled: start with all nodes collapsed
        // User will manually expand what they need
    }
    
    // MARK: - Icon Resolution
    
    private var iconName: String {
        let path = itemPath.lowercased()
        let name = itemName
        
        if name.hasPrefix("smb://") || name.hasPrefix("afp://") || name.hasPrefix("nfs://") {
            return "server.rack"
        }
        if path.hasPrefix("/volumes/") || path == "/volumes" {
            return "externaldrive.fill"
        }
        
        let mapping: [String: String] = [
            "/applications": "square.grid.3x3.fill",
            "/library": "building.columns.fill",
            "/system": "gearshape.fill",
            "/desktop": "desktopcomputer",
            "/documents": "doc.text.fill",
            "/downloads": "arrow.down.circle.fill",
            "/movies": "film.fill",
            "/music": "music.note",
            "/pictures": "photo.fill",
            "/developer": "hammer.fill",
            "/users": "person.2.fill"
        ]
        
        for (folder, icon) in mapping where path.contains(folder) {
            return icon
        }
        
        return isNavigable ? "folder.fill" : "doc.fill"
    }
    
    private var iconColor: Color {
        let path = itemPath.lowercased()
        let name = itemName
        
        if name.hasPrefix("smb://") || name.hasPrefix("afp://") || name.hasPrefix("nfs://") {
            return .blue
        }
        if path.hasPrefix("/volumes/") { return .purple }
        if path.contains("/system") || path.contains("/library") { return .red }
        if path.contains("/applications") { return .green }
        if path.contains("/users") { return .orange }
        
        return isNavigable ? .blue.opacity(0.8) : .secondary
    }
}
