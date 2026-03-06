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
        // View mode toggle — right side
        ToolbarItem(placement: .primaryAction) {
            ViewModeToolbarItem(appState: appState)
        }
        // All action buttons — right side, own framed group
        ToolbarItem(placement: .primaryAction) {
            ToolbarButtonGroup {
                if store.visibleIDs.contains(.refresh) {
                    app.makeToolbarIcon(.refresh) { app.performRefresh() }
                }
                if store.visibleIDs.contains(.hiddenFiles) {
                    app.makeToolbarToggle(.hiddenFiles)
                }
                if store.visibleIDs.contains(.openWith) {
                    app.makeToolbarIcon(.openWith) { app.performOpenWith() }
                }
                if store.visibleIDs.contains(.swapPanels) {
                    app.makeToolbarIcon(.swapPanels) { app.performSwapPanels() }
                }
                if store.visibleIDs.contains(.compare) {
                    app.makeToolbarIcon(.compare) { app.performCompare() }
                }
                if store.visibleIDs.contains(.network) {
                    app.makeToolbarIcon(.network) { app.performNetwork() }
                }
                if store.visibleIDs.contains(.connectServer) {
                    app.makeToolbarIcon(.connectServer) { app.performConnectServer() }
                }
                if store.visibleIDs.contains(.findFiles) {
                    app.makeToolbarIcon(.findFiles) { app.performFindFiles() }
                }
                if store.visibleIDs.contains(.settings) {
                    app.makeToolbarIcon(.settings) { app.performSettings() }
                }
            }
        }
        // Menu bar toggle — rightmost
        ToolbarItem(placement: .primaryAction) {
            ToolbarButtonGroup {
                app.makeToolbarToggle(.menuBarToggle)
            }
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
