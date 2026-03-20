//
// ButtonFavTopPanel.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 17.01.2026.
//             via PanelDialogCoordinator (pattern mirrors FindFilesCoordinator).
// Copyright © 2026 Senatov. All rights reserved.

import AppKit
import FavoritesKit
import FileModelKit
import SwiftUI

private struct NoSelectionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1.0) // subtle feedback, no selection
    }
}

// MARK: - Navigation Panel with Favorites Button
struct ButtonFavTopPanel: View {
    @Environment(AppState.self) var appState
    // MARK: - State
    @State private var favorites: [FavoriteItem] = []
    @State private var navigationAdapter: FavoritesNavigationAdapter?
    let panelSide: PanelSide
    
    
    // Active panel check for icon contrast
    private var isActivePanel: Bool {
        appState.focusedPanel == panelSide
    }

    private var iconColor: Color {
        // darker + sharper — no wishy-washy opacity games
        isActivePanel ? Color(nsColor: .labelColor).opacity(0.75) : Color(nsColor: .labelColor).opacity(0.4)
    }

    // MARK: - Init
    init(selectedSide: PanelSide) {
        log.debug("ButtonFavTopPanel init for side <<\(selectedSide)>>")
        self.panelSide = selectedSide
    }

    // MARK: - Body
    var body: some View {
        navigationControls
            .onAppear {
                if navigationAdapter == nil {
                    navigationAdapter = FavoritesNavigationAdapter(appState: appState)
                }
            }
    }

    // MARK: - Navigation Controls
    private var navigationControls: some View {
        HStack(spacing: 6) {
            navigationGroup
            utilityGroup
        }
        .focusable(false)
    }

    private var navigationGroup: some View {
        HStack(spacing: 6) {
            backButton()
            upButton()
            forwardButton()
        }
    }

    private var utilityGroup: some View {
        HStack(spacing: 6) {
            historyButton()
            favoritesButton()
        }
    }

    private func navIcon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 15))
            .symbolRenderingMode(.multicolor)
            .foregroundStyle(iconColor)
    }

    // MARK: - Back Button
    private func backButton() -> some View {
        let canGoBack = appState.navigationHistory(for: panelSide).canGoBack
        return navIcon("arrowshape.backward")
            .contentShape(Rectangle())
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
            .focusable(false)
            .allowsHitTesting(true)
            .background(Color.clear)
            .help("Click: go back | Ctrl+click: show history")
            .accessibilityLabel("Back button")
    }

    // MARK: - Up Button
    private func upButton() -> some View {
        Button(action: {
            log.debug("Up: navigating to parent directory")
            navigationAdapter?.navigateUp(panel: panelSide.toFavPanelSide)
        }) {
            Image(systemName: "arrowshape.up")
                .font(.system(size: 15))
                .symbolRenderingMode(.multicolor)
                .symbolEffect(.bounce, value: 2)
                .foregroundStyle(iconColor)
        }
        .buttonStyle(NoSelectionButtonStyle())
        .focusable(false)
        .help("Go to parent directory")
        .accessibilityLabel("Up button")
    }

    // MARK: - Forward Button
    private func forwardButton() -> some View {
        let canGoForward = appState.navigationHistory(for: panelSide).canGoForward
        return navIcon("arrowshape.right")
            .contentShape(Rectangle())
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
            .focusable(false)
            .allowsHitTesting(true)
            .background(Color.clear)
            .help("Click: go forward | Ctrl+click: show history")
            .accessibilityLabel("Forward button")
    }

    // MARK: - History Button
    private func historyButton() -> some View {
        Button(action: { openHistoryWindow() }) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 15, weight: .semibold))
                .symbolRenderingMode(.multicolor)
                .foregroundStyle(Color(nsColor: NSColor(calibratedRed: 0.05, green: 0.52, blue: 0.18, alpha: 1.0)))
        }
        .buttonStyle(NoSelectionButtonStyle())
        .focusable(false)
        .help("Show navigation history")
    }

    // MARK: - Favorites Button
    private func favoritesButton() -> some View {
        Button(action: { openFavoritesWindow() }) {
            Image(systemName: panelSide == .left ? "sidebar.left" : "sidebar.right")
                .font(.system(size: 15, weight: .semibold))
                .symbolRenderingMode(.multicolor)
                .foregroundStyle(Color(nsColor: NSColor(calibratedRed: 0.0, green: 0.42, blue: 0.55, alpha: 1.0)))
        }
        .buttonStyle(NoSelectionButtonStyle())
        .focusable(false)
        .help("Navigation between favorites — \(panelSide.rawValue)")
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
