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

    // Active panel check for icon contrast
    private var isActivePanel: Bool {
        appState.focusedPanel == panelSide
    }

    private var iconColor: Color {
        // darker + sharper — no wishy-washy opacity games
        isActivePanel ? Color(nsColor: .labelColor).opacity(0.75) : Color(nsColor: .labelColor).opacity(0.4)
    }

    private var navigator: PathNavigationService {
        PathNavigationService.shared(appState: appState)
    }

    // MARK: - Body
    var body: some View {
        navigationControls
            .onAppear {
                store.load()
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

    // MARK: - Init
    init(selectedSide: FavPanelSide) {
        log.debug("[BreadCrumbToolBar] init panel=\(selectedSide)")
        self.panelSide = selectedSide
    }

    private func navIcon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 15, weight: .light))
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
                if canGoBack {
                    log.info("[Nav] back panel=\(panelSide)")
                    _ = appState.navigationHistory(for: panelSide).goBack()
                }
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
        @State var isHovered = false

        return Button(action: {
            log.debug("[BreadCrumbToolBar] navigate up for panel=\(panelSide)")
            let current = appState.path(for: panelSide)
            let url = URL(fileURLWithPath: current)
            var parent = url.deletingLastPathComponent().path
            // Ensure we don't end up with empty path; keep root
            if parent.isEmpty {
                parent = "/"
            }
            Task {
                await navigator.navigate(to: parent, side: panelSide)
            }
        }) {
            Image(systemName: "arrowshape.up")
                .font(.system(size: 15, weight: .light))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(isHovered ? Color.white : iconColor)
                .frame(width: 28, height: 28)
                .background(
                    ZStack {
                        // Glass base
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(.ultraThinMaterial)

                        // Top highlight (3D light)
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(Color.white.opacity(0.35), lineWidth: 1)
                            .blur(radius: 0.5)
                            .offset(x: -0.5, y: -0.5)
                            .mask(
                                LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: .bottom)
                            )

                        // Bottom shadow (3D depth)
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(Color.black.opacity(0.4), lineWidth: 1)
                            .blur(radius: 0.5)
                            .offset(x: 0.5, y: 0.5)
                            .mask(
                                LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                            )

                        // Hover tint
                        if isHovered {
                            RoundedRectangle(cornerRadius: 7)
                                .fill(Color.blue.opacity(0.25))
                        }
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(Color(red: 0.35, green: 0.55, blue: 0.85).opacity(isHovered ? 0.7 : 0.3), lineWidth: 0.6)
                )
                .scaleEffect(isHovered ? 1.05 : 1.0)
                .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isHovered)
        }
        .buttonStyle(.plain)
        .focusable(false)
        .onHover { hovering in
            isHovered = hovering
        }
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
                if canGoForward {
                    log.info("[Nav] forward panel=\(panelSide)")
                    _ = appState.navigationHistory(for: panelSide).goForward()
                }
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
                .font(.system(size: 15, weight: .light))
                .symbolRenderingMode(.multicolor)
                .foregroundStyle(Color(nsColor: NSColor(calibratedRed: 0.0, green: 0.42, blue: 0.55, alpha: 1.0)))
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
                .font(.system(size: 15, weight: .light))
                .symbolRenderingMode(.multicolor)
                .foregroundStyle(Color(nsColor: NSColor(calibratedRed: 0.0, green: 0.42, blue: 0.55, alpha: 1.0)))
        }
        .buttonStyle(NoSelectionButtonStyle())
        .focusable(false)
        .help("Navigation between favorites — \(panelSide.rawValue)")
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
}
