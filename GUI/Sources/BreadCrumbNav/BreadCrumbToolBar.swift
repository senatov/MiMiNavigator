//
// BreadCrumbToolBar.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 17.01.2026.
//             via PanelDialogCoordinator (pattern mirrors FindFilesCoordinator).
// Copyright © 2026 Senatov. All rights reserved.

import AppKit
import FavoritesKit
import FileModelKit
import SwiftUI

// MARK: - Navigation Panel with Favorites Button
struct BreadCrumbToolBar: View {
    @Environment(AppState.self) var appState
    // MARK: - State
    @StateObject private var store = FavoritesKit.FavoritesStore.shared
    @State private var favNavAdapter: FavNavAdapter? = nil
    let panelSide: FavPanelSide

    private enum Metrics {
        static let groupSpacing: CGFloat = 6
        static let iconSize: CGFloat = 15
        static let buttonSize: CGFloat = 28
    }

    private enum Palette {
        static let activeIcon = Color(nsColor: .labelColor)
        static let inactiveIcon = Color(nsColor: .labelColor).opacity(0.45)
        static let utilityIcon = Color(nsColor: NSColor(calibratedRed: 0.0, green: 0.42, blue: 0.55, alpha: 1.0))
        static let hoverTint = Color.accentColor
    }

    // Active panel check for icon contrast
    private var isActivePanel: Bool {
        appState.focusedPanel == panelSide
    }

    private var iconColor: Color {
        isActivePanel ? Palette.activeIcon : Palette.inactiveIcon
    }

    private var navigator: PathNavigationService {
        PathNavigationService.shared(appState: appState)
    }

    // MARK: - Body
    var body: some View {
        navigationControls
            .onAppear(perform: handleAppear)
    }

    // MARK: - Navigation Controls
    private var navigationControls: some View {
        HStack(spacing: Metrics.groupSpacing) {
            navigationGroup
            utilityGroup
        }
        .focusable(false)
    }

    private var navigationGroup: some View {
        HStack(spacing: Metrics.groupSpacing) {
            backButton()
            upButton()
            forwardButton()
        }
    }

    private var utilityGroup: some View {
        HStack(spacing: Metrics.groupSpacing) {
            historyButton()
            favoritesButton()
        }
    }

    // MARK: - Init
    init(selectedSide: FavPanelSide) {
        log.debug("[BreadCrumbToolBar] init panel=\(selectedSide)")
        self.panelSide = selectedSide
    }

    // MARK: - Back Button
    private func backButton() -> some View {
        let canGoBack = appState.navigationHistory(for: panelSide).canGoBack
        return ToolBarIconButton(
            iconName: "chevron.left",
            iconColor: iconColor,
            isEnabled: canGoBack,
            action: { handleBackTap(canGoBack: canGoBack) }
        )
        .gesture(
            TapGesture(count: 1)
                .modifiers(.control)
                .onEnded { _ in openHistoryWindow() }
        )
        .focusable(false)
        .allowsHitTesting(true)
        .help("Back (Ctrl+click: history)")
    }

    // MARK: - Up Button
    private func upButton() -> some View {
        ToolBarIconButton(
            iconName: "chevron.up",
            iconColor: iconColor,
            action: { handleNavigateUp() }
        )
        .focusable(false)
        .help("Parent directory")
    }

    // MARK: - Forward Button
    private func forwardButton() -> some View {
        let canGoForward = appState.navigationHistory(for: panelSide).canGoForward
        return ToolBarIconButton(
            iconName: "chevron.right",
            iconColor: iconColor,
            isEnabled: canGoForward,
            action: { handleForwardTap(canGoForward: canGoForward) }
        )
        .gesture(
            TapGesture(count: 1)
                .modifiers(.control)
                .onEnded { _ in openHistoryWindow() }
        )
        .focusable(false)
        .allowsHitTesting(true)
        .help("Forward (Ctrl+click: history)")
    }

    // MARK: - History Button
    private func historyButton() -> some View {
        ToolBarIconButton(
            iconName: "clock.arrow.circlepath",
            iconColor: Palette.utilityIcon,
            action: {
                log.debug("[BreadCrumbToolBar] history tapped panel=\(panelSide)")
                openHistoryWindow()
            }
        )
        .focusable(false)
        .help("Navigation history")
    }

    // MARK: - Favorites Button
    private func favoritesButton() -> some View {
        ToolBarIconButton(
            iconName: panelSide == .left ? "sidebar.left" : "sidebar.right",
            iconColor: Palette.utilityIcon,
            action: {
                log.debug("[BreadCrumbToolBar] favorites tapped panel=\(panelSide)")
                openFavoritesWindow()
            }
        )
        .focusable(false)
        .help("Favorites — \(panelSide.rawValue)")
    }

    private func handleAppear() {
        store.load()
    }

    private func handleBackTap(canGoBack: Bool) {
        guard canGoBack else { return }
        log.info("[Nav] back panel=\(panelSide)")
        guard let targetURL = appState.navigationHistory(for: panelSide).goBack() else { return }
        appState.isNavigatingFromHistory = true
        Task {
            defer { appState.isNavigatingFromHistory = false }
            await appState.navigateToDirectory(targetURL.path, on: panelSide)
        }
    }

    private func handleForwardTap(canGoForward: Bool) {
        guard canGoForward else { return }
        log.info("[Nav] forward panel=\(panelSide)")
        guard let targetURL = appState.navigationHistory(for: panelSide).goForward() else { return }
        appState.isNavigatingFromHistory = true
        Task {
            defer { appState.isNavigatingFromHistory = false }
            await appState.navigateToDirectory(targetURL.path, on: panelSide)
        }
    }

    private func handleNavigateUp() {
        log.debug("[BreadCrumbToolBar] navigate up for panel=\(panelSide)")
        Task {
            await appState.navigateToParent(on: panelSide)
        }
    }

    // MARK: - Open History Window

    private func openHistoryWindow() {
        log.debug("[BreadCrumbToolBar] open history window for panel=\(panelSide)")
        let content = HistoryWindowContent(panelSide: panelSide)
            .environment(appState)
        PanelDialogCoordinator.history.open(content: content)
    }

    // MARK: - Open Favorites Window
    private func openFavoritesWindow() {
        log.debug("[BreadCrumbToolBar] open favorites requested for panel=\(panelSide)")
        // Favorites are managed by FavoritesStore
        appState.focusedPanel = panelSide
        // isPresented binding for FavoritesTreeView — toggles close via Esc
        let isPresented = Binding<Bool>(
            get: { PanelDialogCoordinator.favorites.isVisible },
            set: { if !$0 { PanelDialogCoordinator.favorites.close() } }
        )

        if favNavAdapter == nil {
            favNavAdapter = FavNavAdapter(appState: appState)
        }
        let content = FavoritesTreeView(
            items: Binding(
                get: { store.userFavorites },
                set: { newValue in
                    store.replaceAll(newValue)
                }
            ),
            isPresented: isPresented,
            panelSide: panelSide.toFavPanelSide,
            navigationDelegate: favNavAdapter
        )
        log.info("[Favorites] open panel=\(panelSide) items=\(store.userFavorites.count)")
        PanelDialogCoordinator.favorites.open(content: content)
    }

    // MARK: - ToolBarIconButton — clean outline icon, no frame (Meet-style)
    private struct ToolBarIconButton: View {
        let iconName: String
        let iconColor: Color
        var isEnabled: Bool = true
        let action: () -> Void

        @State private var isHovered = false

        var body: some View {
            Button(action: action) {
                Image(systemName: iconName)
                    .font(.system(size: Metrics.iconSize, weight: .light))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isHovered ? Palette.hoverTint : iconColor)
                    .frame(width: Metrics.buttonSize, height: Metrics.buttonSize)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled)
            .opacity(isEnabled ? 1.0 : 0.35)
            .onHover { hovering in
                isHovered = hovering && isEnabled
            }
        }
    }
}
