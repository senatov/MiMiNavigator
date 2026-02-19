//
// FavoritesTreeView.swift
// FavoritesKit
//
// Created by Iakov Senatov on 17.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
//
// Description: Main popup view showing the favorites tree.
// Uses value types for items to avoid index out of range during async updates.

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
        .frame(minWidth: 380, idealWidth: 480, maxWidth: 620)
        .frame(minHeight: 400, idealHeight: 700, maxHeight: 950)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
        .onAppear {
            loadExpandedFolders()
        }
        .onDisappear {
            saveExpandedFolders()
        }
        .onExitCommand {
            isPresented = false
        }
    }
    
    // MARK: - Persistence
    
    private func loadExpandedFolders() {
        if let saved = UserDefaults.standard.stringArray(forKey: Config.expandedFoldersKey) {
            expandedFolders = Set(saved)
        }
    }
    
    private func saveExpandedFolders() {
        // Save only root-level expanded folders (max 5)
        let rootFolders = expandedFolders
            .filter { path in
                // Keep only paths with depth <= 2 from root categories
                let components = path.split(separator: "/").count
                return components <= 6  // e.g., /Users/senat/Library/CloudStorage/OneDrive-Personal
            }
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
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
            
            Spacer(minLength: 0)
            
            Text("\(items.count)")
                .font(.system(size: 11, weight: .medium))
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
    
    // MARK: - File List (uses value types, not Bindings)
    
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
