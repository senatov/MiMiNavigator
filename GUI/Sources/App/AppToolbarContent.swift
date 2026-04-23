// AppToolbarContent.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 24.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Dynamic toolbar content driven by ToolbarStore.
//   All action buttons grouped in a single framed HStack for visual cohesion.
//   Menu bar toggle is separate, also framed.

import SwiftUI

// MARK: - App Toolbar Content
struct AppToolbarContent: ToolbarContent {

    let app: MiMiNavigatorApp
    let appState: AppState

    private var store: ToolbarStore { ToolbarStore.shared }

    // MARK: - Body
    var body: some ToolbarContent {
        // All action buttons — left group
        ToolbarItem(placement: .primaryAction) {
            ToolbarButtonGroup {
                ForEach(store.visibleItems) { item in
                    toolbarButton(for: item)
                }
            }
        }
        // Menu bar toggle
        ToolbarItem(placement: .primaryAction) {
            ToolbarButtonGroup {
                app.makeToolbarToggle(.menuBarToggle)
            }
        }
        // View mode toggle — rightmost, near the title/version badge
        ToolbarItem(placement: .primaryAction) {
            ViewModeToolbarItem(appState: appState)
        }
    }

    @ViewBuilder
    private func toolbarButton(for item: ToolbarItemID) -> some View {
        switch item {
        case .refresh:
            app.makeToolbarIcon(.refresh) { app.performRefresh() }
        case .hiddenFiles:
            app.makeToolbarToggle(.hiddenFiles)
        case .openWith:
            app.makeToolbarIcon(.openWith) { app.performOpenWith() }
        case .swapPanels:
            app.makeToolbarIcon(.swapPanels) { app.performSwapPanels() }
        case .compare:
            app.makeToolbarIcon(.compare) { app.performCompare() }
        case .network:
            app.makeToolbarIcon(.network) { app.performNetwork() }
        case .connectServer:
            app.makeToolbarIcon(.connectServer) { app.performConnectServer() }
        case .findFiles:
            app.makeToolbarIcon(.findFiles) { app.performFindFiles() }
        case .settings:
            app.makeToolbarIcon(.settings) { app.performSettings() }
        case .menuBarToggle:
            EmptyView()
        }
    }
}

// MARK: - Framed Toolbar Button Group
/// Wraps toolbar buttons in a rounded rect with separator border — matches Breadcrumb style.
struct ToolbarButtonGroup<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: 6) {
            content()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.7), lineWidth: 0.5)
        )
    }
}

// MARK: - View Mode Toolbar Item
/// appState passed explicitly — @Environment is unreliable inside ToolbarContent on macOS
private struct ViewModeToolbarItem: View {
    let appState: AppState
    @State private var viewModeStore = PanelViewModeStore.shared

    var body: some View {
        ToolbarButtonGroup {
            let side = appState.focusedPanel
            Picker("", selection: Binding(
                get: { viewModeStore.mode(for: side) },
                set: { viewModeStore.setMode($0, for: side) }
            )) {
                Image(systemName: "list.bullet")
                    .tag(PanelViewMode.list)
                    .help("List view")
                Image(systemName: "square.grid.2x2")
                    .tag(PanelViewMode.thumbnail)
                    .help("Thumbnail view")
            }
            .pickerStyle(.segmented)
            .frame(width: 64)
        }
    }
}
