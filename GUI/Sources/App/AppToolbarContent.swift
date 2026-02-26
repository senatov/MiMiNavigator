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

    private var store: ToolbarStore { ToolbarStore.shared }

    // MARK: - Body
    var body: some ToolbarContent {
        // All action buttons in one framed group
        ToolbarItem(placement: .automatic) {
            ToolbarButtonGroup {
                if store.visibleIDs.contains(.refresh) {
                    app.makeToolbarIcon(.refresh) {
                        app.performRefresh()
                    }
                }
                if store.visibleIDs.contains(.hiddenFiles) {
                    app.makeToolbarToggle(.hiddenFiles)
                }
                if store.visibleIDs.contains(.openWith) {
                    app.makeToolbarIcon(.openWith) {
                        app.performOpenWith()
                    }
                }
                if store.visibleIDs.contains(.swapPanels) {
                    app.makeToolbarIcon(.swapPanels) {
                        app.performSwapPanels()
                    }
                }
                if store.visibleIDs.contains(.compare) {
                    app.makeToolbarIcon(.compare) {
                        app.performCompare()
                    }
                }
                if store.visibleIDs.contains(.network) {
                    app.makeToolbarIcon(.network) {
                        app.performNetwork()
                    }
                }
                if store.visibleIDs.contains(.connectServer) {
                    app.makeToolbarIcon(.connectServer) {
                        app.performConnectServer()
                    }
                }
                if store.visibleIDs.contains(.findFiles) {
                    app.makeToolbarIcon(.findFiles) {
                        app.performFindFiles()
                    }
                }
                if store.visibleIDs.contains(.settings) {
                    app.makeToolbarIcon(.settings) {
                        app.performSettings()
                    }
                }
            }
        }

        // Menu bar toggle — separate framed item
        ToolbarItem(placement: .automatic) {
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
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.75)
        )
    }
}
