// FinderSidebarView.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 27.04.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Finder-style source list embedded in the main dual-panel window.

import AppKit
import FavoritesKit
import FileModelKit
import SwiftUI

// MARK: - Finder Sidebar View
struct FinderSidebarView: View {
    let appState: AppState
    @State private var colorStore = ColorThemeStore.shared
    @State var remoteManager = RemoteConnectionManager.shared
    @StateObject var favoritesStore = FavoritesStore.shared
    @State var volumes: [FinderSidebarItem] = []
    @State var selectedID: String?

    // MARK: - Body
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FinderSidebarLayout.sectionSpacing) {
                section(title: nil, items: topItems)
                section(title: "Favorites", items: favoriteItems)
                section(title: "Locations", items: locationItems)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 34)
        }
        .background(sidebarBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radius, style: .continuous))
        .overlay(sidebarBorder)
        .shadow(color: Color.black.opacity(0.10), radius: 3, x: 0, y: 1)
        .padding(.horizontal, DesignTokens.grid)
        .padding(.vertical, DesignTokens.grid - 2)
        .onAppear(perform: refreshSidebarSources)
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: Notification.Name("NSWorkspaceDidMountNotification"))) { _ in
            refreshVolumes()
        }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: Notification.Name("NSWorkspaceDidUnmountNotification"))) { _ in
            refreshVolumes()
        }
    }

    // MARK: - Sidebar Background
    private var sidebarBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DesignTokens.radius, style: .continuous)
                .fill(DesignTokens.card)
            RoundedRectangle(cornerRadius: DesignTokens.radius, style: .continuous)
                .fill(.ultraThinMaterial)
                .opacity(0.18)
        }
    }

    // MARK: - Sidebar Border
    private var sidebarBorder: some View {
        RoundedRectangle(cornerRadius: DesignTokens.radius, style: .continuous)
            .stroke(
                colorStore.activeTheme.panelBorderActive,
                lineWidth: colorStore.activeTheme.panelBorderWidth
            )
    }
}

// MARK: - Finder Sidebar Layout
enum FinderSidebarLayout {
    static let rowHeight: CGFloat = 26
    static let iconWidth: CGFloat = 18
    static let horizontalPadding: CGFloat = 10
    static let sectionSpacing: CGFloat = 10
}
