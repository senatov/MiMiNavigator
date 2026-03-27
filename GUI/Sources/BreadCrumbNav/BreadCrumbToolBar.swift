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
        static let cornerRadius: CGFloat = 7
        static let borderLineWidth: CGFloat = 0.6
        static let hoverScale: CGFloat = 1.05
    }

    private enum Palette {
        static let activeIcon = Color(nsColor: .labelColor).opacity(0.75)
        static let inactiveIcon = Color(nsColor: .labelColor).opacity(0.4)
        static let utilityIcon = Color(nsColor: NSColor(calibratedRed: 0.0, green: 0.42, blue: 0.55, alpha: 1.0))
        static let hoverFill = Color.blue.opacity(0.25)
        static let topHighlight = Color.white.opacity(0.35)
        static let bottomShadow = Color.black.opacity(0.4)
        static let hoverBorder = Color(#colorLiteral(red: 0.9529411793, green: 0.6862745285, blue: 0.1333333403, alpha: 1))
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

    private func navIcon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: Metrics.iconSize, weight: .light))
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
                handleBackTap(canGoBack: canGoBack)
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
        UpNavigationButton(iconColor: iconColor) {
            handleNavigateUp()
        }
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
                handleForwardTap(canGoForward: canGoForward)
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
        Button(action: {
            log.debug("[BreadCrumbToolBar] history button tapped panel=\(panelSide)")
            openHistoryWindow()
        }) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: Metrics.iconSize, weight: .light))
                .symbolRenderingMode(.multicolor)
                .foregroundStyle(Palette.utilityIcon)
        }
        .buttonStyle(NoSelectionButtonStyle())
        .focusable(false)
        .help("Show navigation history")
    }

    // MARK: - Favorites Button
    private func favoritesButton() -> some View {
        Button(action: {
            log.debug("[BreadCrumbToolBar] favorites button tapped panel=\(panelSide)")
            openFavoritesWindow()
        }) {
            Image(systemName: panelSide == .left ? "sidebar.left" : "sidebar.right")
                .font(.system(size: Metrics.iconSize, weight: .light))
                .symbolRenderingMode(.multicolor)
                .foregroundStyle(Palette.utilityIcon)
        }
        .buttonStyle(NoSelectionButtonStyle())
        .focusable(false)
        .help("Navigation between favorites — \(panelSide.rawValue)")
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

    private struct UpNavigationButton: View {
        let iconColor: Color
        let action: () -> Void

        @State private var isHovered = false

        var body: some View {
            Button(action: action) {
                Image(systemName: "arrowshape.up")
                    .font(.system(size: Metrics.iconSize, weight: .light))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isHovered ? Color.white : iconColor)
                    .frame(width: Metrics.buttonSize, height: Metrics.buttonSize)
                    .background(buttonBackground)
                    .overlay(buttonBorder)
                    .scaleEffect(isHovered ? Metrics.hoverScale : 1.0)
                    .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isHovered)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                isHovered = hovering
            }
        }

        private var buttonBackground: some View {
            ZStack {
                RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)

                RoundedRectangle(cornerRadius: Metrics.cornerRadius)
                    .stroke(Palette.topHighlight, lineWidth: 1)
                    .blur(radius: 0.5)
                    .offset(x: -0.5, y: -0.5)
                    .mask(
                        LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: .bottom)
                    )

                RoundedRectangle(cornerRadius: Metrics.cornerRadius)
                    .stroke(Palette.bottomShadow, lineWidth: 1)
                    .blur(radius: 0.5)
                    .offset(x: 0.5, y: 0.5)
                    .mask(
                        LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                    )

                if isHovered {
                    RoundedRectangle(cornerRadius: Metrics.cornerRadius)
                        .fill(Palette.hoverFill)
                }
            }
        }

        private var buttonBorder: some View {
            RoundedRectangle(cornerRadius: Metrics.cornerRadius)
                .stroke(Palette.hoverBorder.opacity(isHovered ? 0.7 : 0.3), lineWidth: Metrics.borderLineWidth)
        }
    }
}
