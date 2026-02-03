// HistoryPopoverView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 15.01.2025.
//  Copyright © 2025 Senatov. All rights reserved.

import SwiftUI

// MARK: - HistoryPopoverView
struct HistoryPopoverView: View {
    @Environment(AppState.self) var appState
    @Binding var isPresented: Bool
    let panelSide: PanelSide
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 12))
                    .foregroundStyle(.blue)
                
                Text("Navigation History")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Text("\(directoryPaths.count)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.secondary.opacity(0.15)))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            
            Divider().padding(.horizontal, 8)
            
            // Scrollable list
            if directoryPaths.isEmpty {
                emptyView
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(directoryPaths, id: \.self) { path in
                            HistoryItemRow(
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
        }
        .frame(minWidth: 320, idealWidth: 420, maxWidth: 560)
        .frame(minHeight: 300, idealHeight: 600, maxHeight: 900)
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
    
    // MARK: - Empty state
    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            
            Text("No navigation history")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    // MARK: - Directory paths (already filtered in SelectionsHistory)
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
}
