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
    let panelSide: FavPanelSide
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool
    @State private var appeared = false
    @AppStorage("MiMiNavigator.HistoryWindow.sortNewestFirst") private var sortNewestFirst = true
    private let timeColumnWidth: CGFloat = 150
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
        .frame(minWidth: 360, idealWidth: 558, maxWidth: .infinity)
        .frame(minHeight: 360, idealHeight: 768, maxHeight: .infinity)
        .keyboardFocusSection()
        .background(.ultraThinMaterial)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 4)
        .animation(.easeOut(duration: 0.22), value: appeared)
        .onAppear {
            appState.selectionsHistory.cleanRecentSelections()
            isSearchFocused = true
            withAnimation { appeared = true }
        }
        .onExitCommand { PanelDialogCoordinator.history.close() }
    }
    // MARK: - Header Bar (action bar only — title is in titlebar accessory)
    private var headerBar: some View {
        HStack(spacing: 8) {
            Spacer()
            if !filteredItems.isEmpty {
                Text("\(filteredItems.count)")
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(.quaternary))
                if filteredItems.count != directoryItems.count {
                    Text("of \(directoryItems.count)")
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
                .font(.system(size: 14))
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
        if directoryItems.isEmpty {
            emptyStateView
        } else if filteredItems.isEmpty {
            noMatchView
        } else {
            VStack(spacing: 0) {
                columnHeader
                Divider()
                List {
                    ForEach(filteredItems) { item in
                        let path = item.url.path
                        HistoryRow(
                            path: path,
                            addedAt: item.addedAt,
                            timeColumnWidth: timeColumnWidth,
                            highlightText: searchText,
                            onSelect: { navigateToPath(path) },
                            onDelete: { deleteFromHistory(item) }
                        )
                        .listRowSeparator(.hidden)
                    }
                    .onDelete { indexSet in
                        let items = filteredItems
                        for idx in indexSet {
                            deleteFromHistory(items[idx])
                        }
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
                .scrollContentBackground(.hidden)
            }
        }
    }
    // MARK: - Column Header
    private var columnHeader: some View {
        HStack(spacing: 8) {
            Button {
                sortNewestFirst.toggle()
            } label: {
                HStack(spacing: 4) {
                    Text("Date / Time")
                    Image(systemName: sortNewestFirst ? "chevron.down" : "chevron.up")
                        .font(.system(size: 8, weight: .bold))
                }
                .frame(width: timeColumnWidth, alignment: .leading)
            }
            .buttonStyle(.plain)
            .help(sortNewestFirst ? "Newest directories first" : "Oldest directories first")
            Text("Directory")
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(.primary)
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(Color(nsColor: .controlBackgroundColor))
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
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    // MARK: - Data
    private var directoryItems: [RecentHistorySelection] { appState.selectionsHistory.getRecentSelectionItems() }
    private var filteredItems: [RecentHistorySelection] {
        let matching: [RecentHistorySelection]
        if searchText.isEmpty {
            matching = directoryItems
        } else {
            let query = searchText.lowercased()
            matching = directoryItems.filter { $0.url.path.lowercased().contains(query) }
        }
        return matching.sorted {
            sortNewestFirst ? $0.addedAt > $1.addedAt : $0.addedAt < $1.addedAt
        }
    }
    // MARK: - Actions
    private func navigateToPath(_ path: String) {
        log.debug(#function + "(\(path))")
        // Remote URL — reconnect if needed, then navigate
        if let url = URL(string: path), AppState.isRemotePath(url) {
            Task { @MainActor in
                let mgr = RemoteConnectionManager.shared
                if mgr.activeConnection != nil {
                    await appState.navigateToDirectory(path, on: panelSide)
                } else {
                    // Dead — try to reconnect from saved server matching origin
                    let origin = AppState.remoteOrigin(from: path)
                    if let server = RemoteServerStore.shared.servers.first(where: {
                        AppState.remoteOrigin(from: $0.connectionURL?.absoluteString ?? "") == origin
                    }) {
                        let pwd = RemoteServerKeychain.loadPassword(for: server)
                        await mgr.connect(to: server, password: pwd)
                        if mgr.isConnected {
                            await appState.navigateToDirectory(path, on: panelSide)
                        }
                    }
                }
            }
            return
        }
        // Local path
        let localURL = URL(fileURLWithPath: path)
        guard isDirectoryAvailable(localURL) else {
            log.warning("[History] navigate unavailable path='\(path)'")
            return
        }
        appState.isNavigatingFromHistory = true
        Task { @MainActor in
            defer { appState.isNavigatingFromHistory = false }
            await appState.navigateToDirectory(path, on: panelSide)
        }
    }
    // MARK: - Delete from History
    private func deleteFromHistory(_ item: RecentHistorySelection) {
        log.debug(#function + "(\(item.url.path))")
        withAnimation { appState.selectionsHistory.remove(item) }
    }
    // MARK: - Clear History
    private func clearHistory() {
        log.debug(#function + "()")
        withAnimation { appState.selectionsHistory.clear() }
    }
    // MARK: - Availability
    private func isDirectoryAvailable(_ url: URL) -> Bool {
        guard url.isFileURL else { return true }
        guard !AppState.isStaleAppManagedNetworkMountPath(url) else { return false }
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }
}
