//
// ButtonFavTopPanel.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 17.01.2026.
// Refactored: 20.02.2026 — History and Favorites open as standalone NSPanel windows
//             via PanelDialogCoordinator (pattern mirrors FindFilesCoordinator).
// Copyright © 2026 Senatov. All rights reserved.

import AppKit
import FavoritesKit
import SwiftUI

// MARK: - Navigation Panel with Favorites Button
struct ButtonFavTopPanel: View {
    @Environment(AppState.self) var appState

    // MARK: - State
    @State private var favorites: [FavoriteItem] = []
    @State private var navigationAdapter: FavoritesNavigationAdapter?

    let panelSide: PanelSide

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
        .onAppear {
            if navigationAdapter == nil {
                navigationAdapter = FavoritesNavigationAdapter(appState: appState)
            }
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
            networkButton()
        }
    }

    // MARK: - Back Button
    private func backButton() -> some View {
        let canGoBack = appState.navigationHistory(for: panelSide).canGoBack
        return Image(systemName: "arrowshape.backward")
            .renderingMode(.original)
            .contentShape(Rectangle())
            .shadow(color: .gray, radius: 7.0, x: 1, y: 1)
            .opacity(canGoBack ? 1.0 : 0.4)
            .onTapGesture {
                log.debug("\(#function) navigating back")
                navigationAdapter?.navigateBack(panel: panelSide.toFavPanelSide)
            }
            .gesture(
                TapGesture(count: 1)
                    .modifiers(.control)
                    .onEnded { _ in openHistoryWindow() }
            )
            .help("Click: go back | Ctrl+click: show history")
            .accessibilityLabel("Back button")
    }

    // MARK: - Up Button
    private func upButton() -> some View {
        Button(action: {
            log.debug("Up: navigating to parent directory")
            navigationAdapter?.navigateUp(panel: panelSide.toFavPanelSide)
        }) {
            Image(systemName: "arrowshape.up").renderingMode(.original)
        }
        .buttonStyle(.plain)
        .shadow(color: .gray, radius: 7.0, x: 1, y: 1)
        .help("Go to parent directory")
        .accessibilityLabel("Up button")
    }

    // MARK: - Forward Button
    private func forwardButton() -> some View {
        let canGoForward = appState.navigationHistory(for: panelSide).canGoForward
        return Image(systemName: "arrowshape.right")
            .renderingMode(.original)
            .contentShape(Rectangle())
            .shadow(color: .gray, radius: 7.0, x: 1, y: 1)
            .opacity(canGoForward ? 1.0 : 0.4)
            .onTapGesture {
                log.debug("Forward button click: navigating forward")
                navigationAdapter?.navigateForward(panel: panelSide.toFavPanelSide)
            }
            .gesture(
                TapGesture(count: 1)
                    .modifiers(.control)
                    .onEnded { _ in openHistoryWindow() }
            )
            .help("Click: go forward | Ctrl+click: show history")
            .accessibilityLabel("Forward button")
    }

    // MARK: - History Button
    private func historyButton() -> some View {
        Button(action: { openHistoryWindow() }) {
            Image(systemName: "clock.arrow.circlepath")
                .foregroundStyle(.blue)
        }
        .buttonStyle(.plain)
        .shadow(color: .gray, radius: 7.0, x: 1, y: 1)
        .help("Show navigation history")
    }

    // MARK: - Favorites Button
    private func favoritesButton() -> some View {
        Button(action: { openFavoritesWindow() }) {
            Image(systemName: panelSide == .left ? "sidebar.left" : "sidebar.right")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.blue)
                .scaleEffect(CGSize(width: 0.9, height: 1.3), anchor: .leading)
        }
        .shadow(color: .secondary.opacity(0.15), radius: 7.0, x: 1, y: 1)
        .buttonStyle(.plain)
        .help("Navigation between favorites — \(String(describing: panelSide))")
    }

    // MARK: - Network Button
    private func networkButton() -> some View {
        Button(action: {
            log.debug("Network Neighborhood button tapped")
            appState.showNetworkNeighborhood = true
        }) {
            Image(systemName: "network")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.blue)
        }
        .buttonStyle(.plain)
        .shadow(color: .gray, radius: 7.0, x: 1, y: 1)
        .help("Network Neighborhood")
        .accessibilityLabel("Network Neighborhood button")
    }

    // MARK: - Open History Window

    private func openHistoryWindow() {
        let content = HistoryWindowContent(panelSide: panelSide)
            .environment(appState)
        PanelDialogCoordinator.history.open(content: content)
    }

    // MARK: - Open Favorites Window

    private func openFavoritesWindow() {
        log.debug("Navigation between favorites")
        if favorites.isEmpty {
            Task { await loadFavorites() }
        }
        appState.focusedPanel = panelSide

        // isPresented binding for FavoritesTreeView — toggles close via Esc
        let isPresented = Binding<Bool>(
            get: { PanelDialogCoordinator.favorites.isVisible },
            set: { if !$0 { PanelDialogCoordinator.favorites.close() } }
        )

        let content = FavoritesTreeView(
            items: $favorites,
            isPresented: isPresented,
            panelSide: panelSide.toFavPanelSide,
            navigationDelegate: navigationAdapter
        )
        PanelDialogCoordinator.favorites.open(content: content)
    }

    // MARK: - Load Favorites
    @MainActor
    private func loadFavorites() async {
        log.debug(#function)
        let scanner = FavoritesScanner()
        favorites = scanner.scanFavorites()
        let all = await scanner.scanFavoritesAndVolumes()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0.3)) {
            favorites = all
        }
    }
}
