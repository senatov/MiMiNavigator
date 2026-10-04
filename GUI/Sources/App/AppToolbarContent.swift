// AppToolbarContent.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 24.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Dynamic toolbar content driven by ToolbarStore.
//   Action buttons and view controls share a restrained toolbar surface.

import AppKit
import SwiftUI

// MARK: - App Toolbar Content
struct AppToolbarContent: ToolbarContent {

    let app: MiMiNavigatorApp
    let appState: AppState

    private var store: ToolbarStore { ToolbarStore.shared }

    // MARK: - Body
    var body: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            AppWindowTitle(version: MiMiNavigatorApp.appVersion)
        }
        // All action buttons — left group
        ToolbarItem(placement: .primaryAction) {
            ToolbarButtonGroup {
                ViewModeToolbarItem(appState: appState)
                Divider().frame(height: 20)
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
    }

    @ViewBuilder
    private func toolbarButton(for item: ToolbarItemID) -> some View {
        switch item {
        case .refresh:
            app.makeToolbarIcon(.refresh) { app.performRefresh() }
        case .hiddenFiles:
            app.makeToolbarToggle(.hiddenFiles)
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
        case .multiRename:
            app.makeToolbarIcon(.multiRename) { app.performMultiRename() }
        case .settings:
            app.makeToolbarIcon(.settings) { app.performSettings() }
        case .feedback:
            FeedbackToolbarButton(action: FeedbackCoordinator.shared.show)
        case .preview:
            app.makeToolbarToggle(.preview)
        case .menuBarToggle:
            EmptyView()
        }
    }
}

// MARK: - App Window Title
private struct AppWindowTitle: View {
    let version: String

    var body: some View {
        HStack(spacing: 7) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 28, height: 28)
                .offset(y: -2.5)
                .accessibilityHidden(true)
            Text("MiMiNavigator")
                .font(.custom("Academy Engraved LET", size: 16))
                .foregroundStyle(.primary)
            Text("V \(version)")
                .font(.custom("Academy Engraved LET", size: 15))
                .foregroundStyle(.secondary)
        }
        .fixedSize()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("MiMiNavigator version \(version)")
    }
}

// MARK: - Toolbar Button Group
enum TopToolbarMetrics {
    static let height: CGFloat = 32
    static let cornerRadius: CGFloat = 16
}

struct ToolbarButtonGroup<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: 6) {
            content()
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .frame(height: TopToolbarMetrics.height)
        .background { TopToolbarSurface() }
    }
}

// MARK: - Top Toolbar Surface
struct TopToolbarSurface: View {
    var body: some View {
        RoundedRectangle(cornerRadius: TopToolbarMetrics.cornerRadius, style: .continuous)
            .fill(.regularMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: TopToolbarMetrics.cornerRadius, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.26))
            }
            .overlay {
                RoundedRectangle(cornerRadius: TopToolbarMetrics.cornerRadius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.13), lineWidth: 1)
            }
    }
}

// MARK: - View Mode Toolbar Item
/// appState passed explicitly — @Environment is unreliable inside ToolbarContent on macOS
private struct ViewModeToolbarItem: View {
    let appState: AppState

    var body: some View {
        let side = appState.focusedPanel
        let tabManager = appState.tabManager(for: side)
        Picker("", selection: Binding(
            get: { tabManager.activeViewMode },
            set: { tabManager.setActiveViewMode($0) }
        )) {
            Image(systemName: "list.bullet")
                .tag(PanelViewMode.list)
                .help("List view")
            Image(systemName: "square.grid.2x2")
                .tag(PanelViewMode.thumbnail)
                .help("Thumbnail view")
            Image(systemName: "list.bullet.indent")
                .tag(PanelViewMode.tree)
                .help("Tree view")
        }
        .pickerStyle(.segmented)
        .frame(width: 96)
        .accessibilityLabel("File view mode")
    }
}
