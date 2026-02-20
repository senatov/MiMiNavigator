// HistoryWindowContent.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 20.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Content view for the standalone History NSPanel window.
//              Replaces old HistoryPopoverView (popover) with a persistent window.
//              Font: SF Pro Display Light 14 via PanelDialogCoordinator.

import SwiftUI

// MARK: - HistoryWindowContent

struct HistoryWindowContent: View {
    @Environment(AppState.self) var appState
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
        .frame(minWidth: 420, idealWidth: 540, maxWidth: .infinity)
        .frame(minHeight: 300, idealHeight: 600, maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .onAppear { isSearchFocused = true }
        .onExitCommand { PanelDialogCoordinator.history.close() }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 12))
                .foregroundStyle(.blue)

            Text("Navigation History")
                .foregroundStyle(.primary)

            Spacer()

            if !filteredPaths.isEmpty {
                Text("\(filteredPaths.count)")
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.secondary.opacity(0.15)))

                if filteredPaths.count != directoryPaths.count {
                    Text("of \(directoryPaths.count)")
                        .foregroundStyle(.tertiary)
                }

                clearButton
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Search Field

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            TextField("Filter history…", text: $searchText)
                .textFieldStyle(.plain)
                .focused($isSearchFocused)

            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.primary.opacity(0.04)))
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
            Image(systemName: "clock.arrow.circlepath").font(.system(size: 36)).foregroundStyle(.tertiary)
            Text("No navigation history").foregroundStyle(.secondary)
            Text("Visited directories will appear here").font(.system(size: 11)).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
    }

    private var noMatchView: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass").font(.system(size: 24)).foregroundStyle(.tertiary)
            Text("No matches for \"\(searchText)\"").foregroundStyle(.secondary)
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

    // MARK: - Data

    private var directoryPaths: [String] { appState.selectionsHistory.recentSelections }

    private var filteredPaths: [String] {
        guard !searchText.isEmpty else { return directoryPaths }
        let q = searchText.lowercased()
        return directoryPaths.filter { $0.lowercased().contains(q) }
    }

    // MARK: - Actions

    private func navigateToPath(_ path: String) {
        appState.updatePath(path, for: panelSide)
        Task {
            if panelSide == .left {
                await appState.scanner.setLeftDirectory(pathStr: path)
                await appState.refreshLeftFiles()
            } else {
                await appState.scanner.setRightDirectory(pathStr: path)
                await appState.refreshRightFiles()
            }
            // Window stays open — user navigates freely
        }
    }

    private func deleteFromHistory(_ path: String) {
        withAnimation(.easeInOut(duration: 0.2)) { appState.selectionsHistory.remove(path) }
    }

    private func clearHistory() {
        withAnimation(.easeInOut(duration: 0.2)) { appState.selectionsHistory.clear() }
    }
}
