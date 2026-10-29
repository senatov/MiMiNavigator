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
            let actions = store.visibleItems.filter { !$0.isStatusBadge }
            ForEach(0..<((actions.count + 2) / 3), id: \.self) { groupIndex in
                ToolbarActionPod(app: app, appState: appState, items: Array(actions.dropFirst(groupIndex * 3).prefix(3)))
            }
        }
        .sharedBackgroundVisibility(.hidden)
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
private struct ToolbarActionPod: View {
    let app: MiMiNavigatorApp
    let appState: AppState
    let items: [ToolbarItemID]
    @State private var store = ToolbarStore.shared

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element) { index, item in
                if index > 0 {
                    Rectangle()
                        .fill(Color.primary.opacity(0.16))
                        .frame(width: 1, height: 18)
                }
                ToolbarActionButton(app: app, appState: appState, item: item)
            }
        }
        .padding(.horizontal, 4)
        .frame(height: store.labelStyle == .iconAndText ? TopToolbarMetrics.labeledActionHeight : TopToolbarMetrics.height)
        .background { TopToolbarSurface() }
        .padding(.horizontal, 4)
    }
}

// MARK: - Toolbar Action Button
private struct ToolbarActionButton: View {
    let app: MiMiNavigatorApp
    let appState: AppState
    let item: ToolbarItemID
    @State private var store = ToolbarStore.shared
    @State private var isHovered = false

    var body: some View {
        let isActive = switch item {
        case .hiddenFiles: appState.showHiddenFiles
        case .preview: PreviewPaneStore.shared.isVisible
        default: false
        }
        Button {
            performAction()
        } label: {
            VStack(spacing: 1) {
                Image(systemName: item == .hiddenFiles && isActive ? "eye.fill" : item.systemImage)
                    .font(.system(size: 16, weight: .regular))
                    .frame(height: store.labelStyle == .iconAndText ? 23 : TopToolbarMetrics.height)
                if store.labelStyle == .iconAndText {
                    Text(toolbarTitle)
                        .font(.system(size: 9))
                        .lineLimit(1)
                }
            }
            .frame(width: store.labelStyle == .iconAndText ? 48 : 36,
                   height: store.labelStyle == .iconAndText ? TopToolbarMetrics.labeledActionHeight : TopToolbarMetrics.height)
            .contentShape(Rectangle())
        }
        .buttonStyle(MailToolbarButtonStyle(isHovered: isHovered))
        .onHover { isHovered = $0 }
        .accessibilityLabel(item.label)
        .foregroundStyle(isActive ? Color.accentColor : Color.primary)
        .help(item.helpText)
        .accessibilityValue(item == .hiddenFiles || item == .preview ? (isActive ? "On" : "Off") : "")
    }

    private var toolbarTitle: String {
        switch item {
        case .hiddenFiles: "Hidden"
        case .swapPanels: "Swap"
        case .findFiles: "Find"
        case .multiRename: "Rename"
        default: item.label
        }
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
        case .memory, .threads, .buildInfo:
            break
        }
    }
}

// MARK: - Toolbar Button Feedback
private struct MailToolbarButtonStyle: ButtonStyle {
    let isHovered: Bool
    // MARK: - Button Body
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                Capsule()
                    .fill(Color.primary.opacity(configuration.isPressed ? 0.16 : isHovered ? 0.08 : 0))
            }
            .animation(.easeOut(duration: 0.12), value: isHovered)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

// MARK: - App Window Title
private struct AppWindowTitle: View {
    let version: String

    var body: some View {
        HStack(spacing: 6) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 24, height: 24)
                .accessibilityHidden(true)
            Text("MiMiNavigator")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
            Text("V \(version)")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .fixedSize()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("MiMiNavigator version \(version)")
    }
}

// MARK: - Toolbar Button Group
enum TopToolbarMetrics {
    static let height: CGFloat = 38
    static let labeledActionHeight: CGFloat = 50
    static let cornerRadius: CGFloat = 19
    static let borderWidth: CGFloat = 0.75
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
            .fill(Color(nsColor: .controlBackgroundColor))
            .overlay {
                RoundedRectangle(cornerRadius: TopToolbarMetrics.cornerRadius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.15), lineWidth: TopToolbarMetrics.borderWidth)
            }
            .shadow(color: Color.black.opacity(0.12), radius: 1.5, y: 1)
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
        .accessibilityLabel("File view mode")
    }
}
