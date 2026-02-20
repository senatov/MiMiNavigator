//
// FavoritesTreeView.swift
// FavoritesKit
//
// Created by Iakov Senatov on 17.01.2026.
// Refactored: 20.02.2026 — standalone window mode, drag-to-reorder, SF Pro Display Light 14
// Copyright © 2026 Senatov. All rights reserved.
//
// Description: Favorites tree used inside a standalone NSPanel (via PanelDialogCoordinator).
//              Supports drag-to-reorder at the root level.
//              Font is set by the coordinator host (.font(.custom("SF Pro Display", size:14).weight(.light)))

import SwiftUI

// MARK: - FavoritesTreeView

public struct FavoritesTreeView: View {

    // MARK: - Constants
    private enum Config {
        static let expandedFoldersKey = "FavoritesExpandedFolders"
        static let maxSavedExpanded = 5
    }

    // MARK: - Properties
    @Binding var items: [FavoriteItem]
    @Binding var isPresented: Bool
    @State private var expandedFolders: Set<String> = []

    private let panelSide: FavPanelSide
    private weak var navigationDelegate: FavoritesNavigationDelegate?

    // MARK: - Init
    public init(
        items: Binding<[FavoriteItem]>,
        isPresented: Binding<Bool>,
        panelSide: FavPanelSide,
        navigationDelegate: FavoritesNavigationDelegate?
    ) {
        self._items = items
        self._isPresented = isPresented
        self.panelSide = panelSide
        self.navigationDelegate = navigationDelegate
    }

    // MARK: - Body
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerView
            Divider().padding(.horizontal, 8)
            fileListView
        }
        .frame(minWidth: 380, idealWidth: 480, maxWidth: .infinity)
        .frame(minHeight: 300, idealHeight: 700, maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .onAppear { loadExpandedFolders() }
        .onDisappear { saveExpandedFolders() }
        .onExitCommand { isPresented = false }
    }

    // MARK: - Persistence

    private func loadExpandedFolders() {
        if let saved = UserDefaults.standard.stringArray(forKey: Config.expandedFoldersKey) {
            expandedFolders = Set(saved)
        }
    }

    private func saveExpandedFolders() {
        let rootFolders = expandedFolders
            .filter { $0.split(separator: "/").count <= 6 }
            .sorted()
            .prefix(Config.maxSavedExpanded)
        UserDefaults.standard.set(Array(rootFolders), forKey: Config.expandedFoldersKey)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 8) {
            Image(systemName: "star.fill")
                .font(.system(size: 12))
                .foregroundStyle(.yellow)

            Text("Favorites")
                .foregroundStyle(.primary)

            Spacer(minLength: 0)

            Text("\(items.count)")
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.secondary.opacity(0.15)))

            Button(action: grantAccess) {
                Image(systemName: "externaldrive.badge.plus")
                    .font(.system(size: 12))
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.borderless)
            .help("Grant access to a volume…")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - File List with drag-to-reorder

    private var fileListView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                ForEach(items, id: \.id) { item in
                    FavoritesRowView(
                        item: item,
                        expandedFolders: $expandedFolders,
                        isPresented: $isPresented,
                        panelSide: panelSide,
                        navigationDelegate: navigationDelegate
                    )
                }
                .onMove { fromOffsets, toOffset in
                    items.move(fromOffsets: fromOffsets, toOffset: toOffset)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Actions

    private func grantAccess() {
        Task { @MainActor in
            _ = await FavoritesBookmarkStore.shared.requestAccessPersisting(
                for: URL(fileURLWithPath: "/Volumes"),
                anchorWindow: nil
            )
        }
    }
}
