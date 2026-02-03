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
    
    @State private var hoveredPath: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSection
            Divider().padding(.horizontal, 8)
            contentSection
        }
        .frame(width: 380)
        .frame(minHeight: 200, maxHeight: 600)
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
        .help("Clear history")
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
                    HistoryItemRow(
                        path: path,
                        isHovered: hoveredPath == path,
                        onHover: { hoveredPath = $0 ? path : nil },
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

// MARK: - History Item Row

struct HistoryItemRow: View {
    let path: String
    var isHovered: Bool = false
    var onHover: ((Bool) -> Void)?
    let onSelect: () -> Void
    let onDelete: () -> Void
    
    private var displayName: String {
        URL(fileURLWithPath: path).lastPathComponent
    }
    
    private var parentPath: String {
        let parent = URL(fileURLWithPath: path).deletingLastPathComponent().path
        return parent == "/" ? "/" : parent
    }
    
    private var iconName: String {
        let pathLower = path.lowercased()
        
        if pathLower.hasPrefix("/volumes/") { return "externaldrive.fill" }
        if pathLower.contains("/applications") { return "square.grid.3x3.fill" }
        if pathLower.contains("/desktop") { return "desktopcomputer" }
        if pathLower.contains("/documents") { return "doc.text.fill" }
        if pathLower.contains("/downloads") { return "arrow.down.circle.fill" }
        if pathLower.contains("/movies") { return "film.fill" }
        if pathLower.contains("/music") { return "music.note" }
        if pathLower.contains("/pictures") { return "photo.fill" }
        
        return "folder.fill"
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .font(.system(size: 14))
                .foregroundStyle(.blue.opacity(0.8))
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
            
            Spacer()
            
            if isHovered {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isHovered ? Color.primary.opacity(0.06) : .clear)
        )
        .contentShape(Rectangle())
        .onHover { onHover?($0) }
        .onTapGesture(perform: onSelect)
        .help(path)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }
}
