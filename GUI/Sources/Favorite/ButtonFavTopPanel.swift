//
// ButtonFavTopPanel.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 17.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
//
// Migrated to use FavoritesKit package

import AppKit
import FavoritesKit
import SwiftUI

// MARK: - Navigation Panel with Favorites Button
struct ButtonFavTopPanel: View {
    @Environment(AppState.self) var appState
    
    // MARK: - State (using FavoritesKit types)
    @State private var favorites: [FavoriteItem] = []
    @State private var showHistoryPopover: Bool = false
    @State private var showFavTreePopup: Bool = false
    
    let panelSide: PanelSide
    
    // MARK: - Navigation adapter for FavoritesKit
    private var navigationAdapter: FavoritesNavigationAdapter {
        FavoritesNavigationAdapter(appState: appState)
    }

    // MARK: - Init
    init(selectedSide: PanelSide) {
        log.debug("ButtonFavTopPanel init for side <<\(selectedSide)>>")
        self.panelSide = selectedSide
    }

    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            navigationControls
        }
    }

    // MARK: - Navigation Controls
    private var navigationControls: some View {
        HStack(spacing: 6) {
            backButton()
            upButton()
            forwardButton()
            historyButton()
            favoritesButton()
        }
    }

    // MARK: - Back Button
    private func backButton() -> some View {
        Image(systemName: "arrowshape.backward")
            .renderingMode(.original)
            .contentShape(Rectangle())
            .shadow(color: .gray, radius: 7.0, x: 1, y: 1)
            .opacity(appState.selectionsHistory.canGoBack ? 1.0 : 0.4)
            .onTapGesture {
                log.debug("Back button click: navigating back")
                navigationAdapter.navigateBack(panel: panelSide.toFavPanelSide)
            }
            .gesture(
                TapGesture(count: 1)
                    .modifiers(.control)
                    .onEnded { _ in showHistoryPopover = true }
            )
            .help("Click: go back | Ctrl+click: show history")
            .accessibilityLabel("Back button")
    }

    // MARK: - Up Button
    private func upButton() -> some View {
        Button(action: {
            log.debug("Up: navigating to parent directory")
            navigationAdapter.navigateUp(panel: panelSide.toFavPanelSide)
        }) {
            Image(systemName: "arrowshape.up")
                .renderingMode(.original)
        }
        .buttonStyle(.plain)
        .shadow(color: .gray, radius: 7.0, x: 1, y: 1)
        .help("Go to parent directory")
        .accessibilityLabel("Up button")
    }

    // MARK: - Forward Button
    private func forwardButton() -> some View {
        Image(systemName: "arrowshape.right")
            .renderingMode(.original)
            .contentShape(Rectangle())
            .shadow(color: .gray, radius: 7.0, x: 1, y: 1)
            .opacity(appState.selectionsHistory.canGoForward ? 1.0 : 0.4)
            .onTapGesture {
                log.debug("Forward button click: navigating forward")
                navigationAdapter.navigateForward(panel: panelSide.toFavPanelSide)
            }
            .gesture(
                TapGesture(count: 1)
                    .modifiers(.control)
                    .onEnded { _ in showHistoryPopover = true }
            )
            .help("Click: go forward | Ctrl+click: show history")
            .accessibilityLabel("Forward button")
    }

    // MARK: - History Button
    private func historyButton() -> some View {
        Button(action: { showHistoryPopover.toggle() }) {
            Image(systemName: "clock.arrow.circlepath")
                .foregroundStyle(.blue)
        }
        .buttonStyle(.plain)
        .shadow(color: .gray, radius: 7.0, x: 1, y: 1)
        .popover(isPresented: $showHistoryPopover, arrowEdge: .bottom) {
            HistoryPopoverView(isPresented: $showHistoryPopover, panelSide: panelSide)
        }
        .help("Show navigation history")
    }

    // MARK: - Favorites Button (using FavoritesKit)
    private func favoritesButton() -> some View {
        Button(action: {
            log.debug("Navigation between favorites")
            if favorites.isEmpty {
                Task { await loadFavorites() }
            }
            appState.focusedPanel = panelSide
            showFavTreePopup.toggle()
        }) {
            Image(systemName: panelSide == .left ? "sidebar.left" : "sidebar.right")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.blue)
                .scaleEffect(CGSize(width: 0.9, height: 1.3), anchor: .leading)
        }
        .shadow(color: .secondary.opacity(0.15), radius: 7.0, x: 1, y: 1)
        .buttonStyle(.plain)
        .popover(isPresented: $showFavTreePopup, arrowEdge: .bottom) {
            favoritesPopover()
                .interactiveDismissDisabled()
        }
        .help("Navigation between favorites - \(panelSide)")
    }

    // MARK: - Favorites Popover (FavoritesKit)
    private func favoritesPopover() -> some View {
        FavoritesTreeView(
            items: $favorites,
            isPresented: $showFavTreePopup,
            panelSide: panelSide.toFavPanelSide,
            navigationDelegate: navigationAdapter
        )
        .padding(6)
        .font(.custom("Helvetica Neue", size: 11).weight(.light))
        .foregroundStyle(FilePanelStyle.fileNameColor)
    }

    // MARK: - Load Favorites (using FavoritesKit scanner)
    @MainActor
    private func loadFavorites() async {
        log.debug(#function)
        let scanner = FavoritesScanner()
        
        // First load quick favorites
        let quickFavorites = scanner.scanFavorites()
        favorites = quickFavorites
        
        // Then load volumes with animation
        let allFavorites = await scanner.scanFavoritesAndVolumes()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0.3)) {
            favorites = allFavorites
        }
    }
}
