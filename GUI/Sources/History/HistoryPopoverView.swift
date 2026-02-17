// HistoryPopoverView.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 15.01.2025.
// Refactored: 14.02.2026 — search filter, chronological order, wider layout
// Copyright © 2025-2026 Senatov. All rights reserved.
// Description: Navigation history popover with search filter and scrollable list

import SwiftUI

// MARK: - HistoryPopoverView
struct HistoryPopoverView: View {
    @Environment(AppState.self) var appState
    @Binding var isPresented: Bool
    let panelSide: PanelSide

    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSection
            searchField
            Divider().padding(.horizontal, 8)
            contentSection
        }
        .frame(width: 540)
        .frame(minHeight: 280, maxHeight: 820)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
        .onExitCommand {
            isPresented = false
        }
        .onAppear {
            isSearchFocused = true
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

            if !filteredPaths.isEmpty {
                Text("\(filteredPaths.count)")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.secondary.opacity(0.15)))

                if filteredPaths.count != directoryPaths.count {
                    Text("of \(directoryPaths.count)")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }

                clearButton
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Search Filter

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            TextField("Filter history…", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .focused($isSearchFocused)

            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
        .padding(.horizontal, 10)
        .padding(.bottom, 6)
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
        } else if filteredPaths.isEmpty {
            noMatchView
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

    private var noMatchView: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 24))
                .foregroundStyle(.tertiary)

            Text("No matches for \"\(searchText)\"")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var historyListView: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(filteredPaths, id: \.self) { path in
                    HistoryRow(
                        path: path,
                        highlightText: searchText,
                        onSelect: { navigateToPath(path) },
                        onDelete: { deleteFromHistory(path) }
                    )
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
    }

    // MARK: - Data (chronological order — newest first, no duplicates)

    private var directoryPaths: [String] {
        appState.selectionsHistory.recentSelections
    }

    private var filteredPaths: [String] {
        guard !searchText.isEmpty else { return directoryPaths }
        let query = searchText.lowercased()
        return directoryPaths.filter { $0.lowercased().contains(query) }
    }

    // MARK: - Actions

    private func navigateToPath(_ path: String) {
        // Update path through AppState to record in navigation history
        appState.updatePath(path, for: panelSide)
        
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
