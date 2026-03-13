// HistoryWindowContent.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 20.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Content view for the standalone History NSPanel window.
//              macOS 26 glass style with inset list, scroll-clipped frame, subtle animations.

import FileModelKit
import SwiftUI

// MARK: - HistoryWindowContent
struct HistoryWindowContent: View {
    @Environment(AppState.self) var appState
    let panelSide: PanelSide
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool
    @State private var appeared = false
    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSection
                .padding(.top, 6)
            searchField
                .padding(.top, 4)
            Divider()
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            listContainer
        }
        .frame(minWidth: 440, idealWidth: 560, maxWidth: .infinity)
        .frame(minHeight: 320, idealHeight: 620, maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 6)
        .animation(.easeOut(duration: 0.25), value: appeared)
        .onAppear {
            isSearchFocused = true
            appeared = true
        }
        .onExitCommand { PanelDialogCoordinator.history.close() }
    }
    // MARK: - Header
    private var headerSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.blue)
            Text("Navigation History")
                .font(.system(size: 13, weight: .semibold, design: .default))
                .foregroundStyle(.primary)
            Spacer()
            if !filteredURLs.isEmpty {
                Text("\(filteredURLs.count)")
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.secondary.opacity(0.12)))
                if filteredURLs.count != directoryURLs.count {
                    Text("of \(directoryURLs.count)")
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
                clearButton
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }
    // MARK: - Search Field
    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            TextField("Filter history…", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($isSearchFocused)
            if !searchText.isEmpty {
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { searchText = "" }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.primary.opacity(0.04))
                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 2)
    }
    // MARK: - Clear Button
    private var clearButton: some View {
        Button(action: clearHistory) {
            Image(systemName: "trash")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.borderless)
        .help("Clear all history")
    }
    // MARK: - List Container (inset bordered ScrollView)
    @ViewBuilder
    private var listContainer: some View {
        if directoryURLs.isEmpty {
            emptyStateView
        } else if filteredURLs.isEmpty {
            noMatchView
        } else {
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: 1) {
                    ForEach(filteredURLs, id: \.path) { url in
                        let path = url.path
                        HistoryRow(
                            path: path,
                            highlightText: searchText,
                            onSelect: { navigateToPath(path) },
                            onDelete: { deleteFromHistory(url) }
                        )
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                    }
                }
                .padding(6)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
            )
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.35))
            )
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
        }
    }
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 34))
                .foregroundStyle(.tertiary)
            Text("No navigation history")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            Text("Visited directories will appear here")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
    }
    // MARK: - No Match
    private var noMatchView: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 22))
                .foregroundStyle(.tertiary)
            Text("No matches for \"\(searchText)\"")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    // MARK: - Data
    private var directoryURLs: [URL] { appState.selectionsHistory.getRecentSelections() }
    private var filteredURLs: [URL] {
        guard !searchText.isEmpty else { return directoryURLs }
        let q = searchText.lowercased()
        return directoryURLs.filter { $0.path.lowercased().contains(q) }
    }
    // MARK: - Actions
    private func navigateToPath(_ path: String) {
        log.debug(#function + "(\(path))")
        appState.updatePath(path, for: panelSide)
        Task {
            if panelSide == .left {
                await appState.scanner.setLeftDirectory(pathStr: path)
                await appState.refreshLeftFiles()
            } else {
                await appState.scanner.setRightDirectory(pathStr: path)
                await appState.refreshRightFiles()
            }
        }
    }
    // MARK: - Delete from History
    private func deleteFromHistory(_ url: URL) {
        log.debug(#function + "(\(url.path))")
        withAnimation(.easeInOut(duration: 0.2)) {
            appState.selectionsHistory.remove(url)
        }
    }
    // MARK: - Clear History
    private func clearHistory() {
        log.debug(#function + "()")
        withAnimation(.easeInOut(duration: 0.25)) {
            appState.selectionsHistory.clear()
        }
    }
}
