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
        ToolbarItemGroup(placement: .primaryAction) {
            ForEach(store.visibleItems) { item in
                ToolbarActionButton(app: app, appState: appState, item: item)
            }
        }
        .sharedBackgroundVisibility(.visible)
        // View modes — separate group before the rightmost menu toggle
        ToolbarItem(placement: .primaryAction) {
            ToolbarButtonGroup {
                ViewModeToolbarItem(appState: appState)
            }
        }
        .visibilityPriority(.high)
        // Menu bar toggle
        ToolbarItem(placement: .primaryAction) {
            ToolbarButtonGroup {
                app.makeToolbarToggle(.menuBarToggle)
            }
        }
        .visibilityPriority(.high)
    }
}

// MARK: - Toolbar Action Button
private struct ToolbarActionButton: View {
    let app: MiMiNavigatorApp
    let appState: AppState
    let item: ToolbarItemID

    var body: some View {
        let isActive = switch item {
        case .hiddenFiles: appState.showHiddenFiles
        case .preview: PreviewPaneStore.shared.isVisible
        default: false
        }
        Button(item.label, systemImage: item == .hiddenFiles && isActive ? "eye.fill" : item.systemImage) {
            performAction()
        }
        .labelStyle(.iconOnly)
        .accessibilityLabel(item.label)
        .foregroundStyle(isActive ? Color.accentColor : Color.primary)
        .help(item.helpText)
        .accessibilityValue(item == .hiddenFiles || item == .preview ? (isActive ? "On" : "Off") : "")
    }

    // MARK: - Toolbar Action
    private func performAction() {
        switch item {
        case .refresh:
            app.performRefresh()
        case .hiddenFiles:
            app.performToggleHidden()
        case .swapPanels:
            app.performSwapPanels()
        case .compare:
            app.performCompare()
        case .network:
            app.performNetwork()
        case .connectServer:
            app.performConnectServer()
        case .findFiles:
            app.performFindFiles()
        case .multiRename:
            app.performMultiRename()
        case .settings:
            app.performSettings()
        case .feedback:
            FeedbackCoordinator.shared.show()
        case .preview:
            PreviewPaneStore.shared.toggle(sourceSide: appState.focusedPanel)
        case .menuBarToggle:
            ToolbarStore.shared.menuBarVisible.toggle()
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
    static let borderWidth: CGFloat = 1
}

struct ToolbarButtonGroup<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: 3) {
            content()
        }
        .padding(.horizontal, 6)
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
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.88))
            }
            .overlay {
                RoundedRectangle(cornerRadius: TopToolbarMetrics.cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.20), Color.primary.opacity(0.025)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: TopToolbarMetrics.cornerRadius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.18), lineWidth: TopToolbarMetrics.borderWidth)
            }
            .shadow(color: Color.black.opacity(0.20), radius: 2.5, y: 1.5)
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
