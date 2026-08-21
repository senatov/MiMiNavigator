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
    enum Content {
        case navigation
        case utilities
    }

    @Environment(AppState.self) var appState
    // MARK: - State
    @StateObject private var store = FavoritesKit.FavoritesStore.shared
    @State private var favNavAdapter: FavNavAdapter? = nil
    let panelSide: FavPanelSide
    let content: Content

    private enum Metrics {
        static let groupSpacing: CGFloat = 6
        static let iconSize: CGFloat = 15
        static let buttonSize: CGFloat = 28
        static let raisedButtonHeight: CGFloat = 24
        static let raisedCornerRadius: CGFloat = 7
    }

    private enum Palette {
        static let activeIcon = Color(nsColor: .labelColor)
        static let inactiveIcon = Color(nsColor: .labelColor).opacity(0.45)
        static let historyIcon = Color(#colorLiteral(red: 0.07843137255, green: 0.3764705882, blue: 0.7058823529, alpha: 1))
        static let favoritesIcon = Color(#colorLiteral(red: 0.6980392157, green: 0.3137254902, blue: 0.04705882353, alpha: 1))
        static let hoverTint = Color(#colorLiteral(red: 0.3058823529, green: 0.1450980392, blue: 0.5294117647, alpha: 1))
    }

    // Active panel check for icon contrast
    private var isActivePanel: Bool {
        appState.focusedPanel == panelSide
    }

    private var iconColor: Color {
        isActivePanel ? Palette.activeIcon : Palette.inactiveIcon
    }

    // MARK: - Body
    var body: some View {
        Group {
            switch content {
                case .navigation:
                    navigationGroup
                case .utilities:
                    utilityGroup
            }
        }
        .keyboardFocusSection()
        .onAppear(perform: handleAppear)
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
    init(selectedSide: FavPanelSide, content: Content = .navigation) {
        log.debug("[BreadCrumbToolBar] init panel=\(selectedSide)")
        self.panelSide = selectedSide
        self.content = content
    }

    // MARK: - Back Button
    private func backButton() -> some View {
        let canGoBack = appState.navigationHistory(for: panelSide).canGoBack
        return ToolBarIconButton(
            iconName: "arrowshape.turn.up.backward",
            iconColor: iconColor,
            surfaceTint: Color.accentColor,
            isEnabled: canGoBack,
            isRaised: true,
            action: { handleBackTap(canGoBack: canGoBack) }
        )
        .gesture(
            TapGesture(count: 1)
                .modifiers(.control)
                .onEnded { _ in openHistoryWindow() }
        )
        .keyboardFocusable()
        .allowsHitTesting(true)
        .help("Back (Ctrl+click: history)")
    }

    // MARK: - Up Button
    private func upButton() -> some View {
        ToolBarIconButton(
            iconName: "arrowshape.up",
            iconColor: iconColor,
            surfaceTint: Color.accentColor,
            isRaised: true,
            action: { handleNavigateUp() }
        )
        .keyboardFocusable()
        .help("Parent directory")
    }

    // MARK: - Forward Button
    private func forwardButton() -> some View {
        let canGoForward = appState.navigationHistory(for: panelSide).canGoForward
        return ToolBarIconButton(
            iconName: "arrowshape.turn.up.forward",
            iconColor: iconColor,
            surfaceTint: Color.accentColor,
            isEnabled: canGoForward,
            isRaised: true,
            action: { handleForwardTap(canGoForward: canGoForward) }
        )
        .gesture(
            TapGesture(count: 1)
                .modifiers(.control)
                .onEnded { _ in openHistoryWindow() }
        )
        .keyboardFocusable()
        .allowsHitTesting(true)
        .help("Forward (Ctrl+click: history)")
    }

    // MARK: - History Button
    private func historyButton() -> some View {
        ToolBarIconButton(
            iconName: "clock.arrow.circlepath",
            iconColor: Palette.historyIcon,
            surfaceTint: Palette.historyIcon,
            isRaised: true,
            action: {
                log.debug("[BreadCrumbToolBar] history tapped panel=\(panelSide)")
                openHistoryWindow()
            }
        )
        .keyboardFocusable()
        .help("Navigation history")
    }

    // MARK: - Favorites Button
    private func favoritesButton() -> some View {
        ToolBarIconButton(
            iconName: panelSide == .left ? "sidebar.left" : "sidebar.right",
            iconColor: Palette.favoritesIcon,
            surfaceTint: Palette.favoritesIcon,
            isRaised: true,
            action: {
                log.debug("[BreadCrumbToolBar] favorites tapped panel=\(panelSide)")
                openFavoritesWindow()
            }
        )
        .keyboardFocusable()
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
        var surfaceTint: Color = .clear
        var isEnabled: Bool = true
        var isRaised: Bool = false
        let action: () -> Void

        @State private var isHovered = false

        var body: some View {
            Button(action: action) {
                Image(systemName: iconName)
                    .font(.system(size: Metrics.iconSize, weight: isRaised ? .medium : .light))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isHovered ? Palette.hoverTint : iconColor)
                    .frame(
                        width: Metrics.buttonSize,
                        height: isRaised ? Metrics.raisedButtonHeight : Metrics.buttonSize
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(width: Metrics.buttonSize, height: isRaised ? Metrics.raisedButtonHeight : Metrics.buttonSize)
            .background { raisedBackground }
            .overlay { raisedBorder }
            .shadow(
                color: isRaised ? Color.black.opacity(isHovered ? 0.24 : 0.17) : .clear,
                radius: isHovered ? 2.2 : 1.4,
                x: 0,
                y: isHovered ? 1.4 : 1
            )
            .disabled(!isEnabled)
            .opacity(isEnabled ? 1.0 : 0.35)
            .onHover { hovering in
                isHovered = hovering && isEnabled
            }
        }

        @ViewBuilder
        private var raisedBackground: some View {
            if isRaised {
                RoundedRectangle(cornerRadius: Metrics.raisedCornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isHovered ? 1 : 0.96),
                                surfaceTint.opacity(isHovered ? 0.18 : 0.11),
                                Color(nsColor: .controlBackgroundColor).opacity(0.94)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
        }

        @ViewBuilder
        private var raisedBorder: some View {
            if isRaised {
                RoundedRectangle(cornerRadius: Metrics.raisedCornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.95), iconColor.opacity(isHovered ? 0.72 : 0.48)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: isHovered ? 1.15 : 0.95
                    )
                    .overlay(alignment: .top) {
                        Capsule()
                            .fill(Color.white.opacity(0.7))
                            .frame(height: 1)
                            .padding(.horizontal, 5)
                            .padding(.top, 1)
                    }
            }
        }
    }
}
