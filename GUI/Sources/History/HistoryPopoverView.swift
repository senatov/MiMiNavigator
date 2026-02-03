// HistoryPopoverView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 15.01.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//
// Description: Navigation history popover with scrollable list

import SwiftUI

// MARK: - HistoryPopoverView
struct HistoryPopoverView: View {
    @Environment(AppState.self) var appState
    @Binding var isPresented: Bool
    let panelSide: PanelSide
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSection
            Divider().padding(.horizontal, 8)
            contentSection
        }
        .frame(width: 360)
        .frame(minHeight: 180, maxHeight: 550)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
        .onExitCommand {
            isPresented = false
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 12))
                .foregroundStyle(.blue)
            
            Text("Navigation History")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
            
            Spacer()
            
            if !directoryPaths.isEmpty {
                Text("\(directoryPaths.count)")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.secondary.opacity(0.15)))
                
                clearButton
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
    
    private var clearButton: some View {
        Button(action: clearHistory) {
            Image(systemName: "trash")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.borderless)
        .help("Clear all history")
    }
    
    // MARK: - Content
    
    @ViewBuilder
    private var contentSection: some View {
        if directoryPaths.isEmpty {
            emptyStateView
        } else {
            historyListView
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            
            Text("No navigation history")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            
            Text("Visited directories will appear here")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
    }
    
    private var historyListView: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(directoryPaths, id: \.self) { path in
                    HistoryRow(
                        path: path,
                        onSelect: { navigateToPath(path) },
                        onDelete: { deleteFromHistory(path) }
                    )
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
    }
    
    // MARK: - Data
    
    private var directoryPaths: [String] {
        appState.selectionsHistory.recentSelections
    }
    
    // MARK: - Actions
    
    private func navigateToPath(_ path: String) {
        Task {
            if panelSide == .left {
                await appState.scanner.setLeftDirectory(pathStr: path)
                await appState.refreshLeftFiles()
            } else {
                await appState.scanner.setRightDirectory(pathStr: path)
                await appState.refreshRightFiles()
            }
            isPresented = false
        }
    }
    
    private func deleteFromHistory(_ path: String) {
        withAnimation(.easeInOut(duration: 0.2)) {
            appState.selectionsHistory.remove(path)
        }
    }
    
    private func clearHistory() {
        withAnimation(.easeInOut(duration: 0.2)) {
            appState.selectionsHistory.clear()
        }
    }
}

// MARK: - History Row (private)

private struct HistoryRow: View {
    let path: String
    let onSelect: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovered = false
    
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
