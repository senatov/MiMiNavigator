// HistoryWindowContent.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 20.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Content view for the standalone History NSPanel window.
//              macOS 26 design: edge-to-edge content, system materials, progressive blur.
//              Glass reserved for floating controls only (HIG 26).

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
        VStack(spacing: 0) {
            headerBar
            searchField
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            Divider()
            listArea
        }
        .frame(minWidth: 440, idealWidth: 560, maxWidth: .infinity)
        .frame(minHeight: 320, idealHeight: 620, maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 4)
        .animation(.easeOut(duration: 0.22), value: appeared)
        .onAppear {
            isSearchFocused = true
            withAnimation { appeared = true }
        }
        .onExitCommand { PanelDialogCoordinator.history.close() }
    }
    // MARK: - Header Bar (action bar only — title is in titlebar accessory)
    private var headerBar: some View {
        HStack(spacing: 8) {
            Spacer()
            if !filteredURLs.isEmpty {
                Text("\(filteredURLs.count)")
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(.quaternary))
                if filteredURLs.count != directoryURLs.count {
                    Text("of \(directoryURLs.count)")
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
                clearButton
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
    // MARK: - Search Field
    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            TextField("Filter history…", text: $searchText)
                .textFieldStyle(.roundedBorder)
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
                .transition(.opacity)
            }
        }
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
    // MARK: - List Area (system inset grouped list, auto scroll + border)
    @ViewBuilder
    private var listArea: some View {
        if directoryURLs.isEmpty {
            emptyStateView
        } else if filteredURLs.isEmpty {
            noMatchView
        } else {
            List {
                ForEach(filteredURLs, id: \.path) { url in
                    let path = url.path
                    HistoryRow(
                        path: path,
                        highlightText: searchText,
                        onSelect: { navigateToPath(path) },
                        onDelete: { deleteFromHistory(url) }
                    )
                    .listRowSeparator(.hidden)
                }
                .onDelete { indexSet in
                    let urls = filteredURLs
                    for idx in indexSet {
                        deleteFromHistory(urls[idx])
                    }
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
            .scrollContentBackground(.hidden)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        // Remote URL — reconnect if needed, then navigate
        if let url = URL(string: path), AppState.isRemotePath(url) {
            Task { @MainActor in
                let mgr = RemoteConnectionManager.shared
                if mgr.activeConnection != nil {
                    // Connection alive — just navigate
                    appState.updatePath(path, for: panelSide)
                    await appState.refreshRemoteFiles(for: panelSide)
                } else {
                    // Dead — try to reconnect from saved server matching origin
                    let origin = AppState.remoteOrigin(from: path)
                    if let server = RemoteServerStore.shared.servers.first(where: {
                        AppState.remoteOrigin(from: $0.connectionURL?.absoluteString ?? "") == origin
                    }) {
                        let pwd = RemoteServerKeychain.loadPassword(for: server)
                        await mgr.connect(to: server, password: pwd)
                        if mgr.isConnected {
                            appState.updatePath(path, for: panelSide)
                            await appState.refreshRemoteFiles(for: panelSide)
                        }
                    }
                }
            }
            return
        }
        // Local path
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
        withAnimation { appState.selectionsHistory.remove(url) }
    }
    // MARK: - Clear History
    private func clearHistory() {
        log.debug(#function + "()")
        withAnimation { appState.selectionsHistory.clear() }
    }
}
