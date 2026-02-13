// HistoryPopoverView.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 15.01.2025.
// Refactored: 13.02.2026 — extracted HistoryRow to separate file
// Copyright © 2025-2026 Senatov. All rights reserved.
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
