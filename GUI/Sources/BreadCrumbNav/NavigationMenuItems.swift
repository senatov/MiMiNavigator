// NavigationMenuItems.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 10.05.2024.
// Copyright © 2024-2026 Senatov. All rights reserved.
// Description: Navigation menu components for breadcrumb panel

import AppKit
import FileModelKit
import SwiftUI

// MARK: - Favorites Button Section (left side of breadcrumb)
struct FavoritesButtonSection: View {
    @Environment(AppState.self) var appState
    let panelSide: PanelSide

    init(selectedSide: PanelSide) {
        self.panelSide = selectedSide
        log.info("FavoritesButtonSection init for side <<\(selectedSide)>>")
    }

    var body: some View {
        log.verbose("FavoritesButtonSection.body")
        return HStack(spacing: 4) {
            ButtonFavTopPanel(selectedSide: panelSide)
        }
        .padding(.leading, 6)
        .task { @MainActor in
            appState.focusedPanel = panelSide
        }
    }
}

// MARK: - Ellipsis Menu Section (right side of breadcrumb)
struct EllipsisMenuSection: View {
    @State private var isHovering = false
    @Environment(AppState.self) var appState

    var body: some View {
        Menu {
            Button("Get Info", action: handleGetInfo)
            Button("Open in Finder", action: handleOpenInFinder)
            Divider()
            Button("Copy Path", action: handleCopyPath)
        } label: {
            Image(systemName: "ellipsis")
                .rotationEffect(.degrees(90))
                .symbolEffect(.scale.up, isActive: isHovering)
                .onHover { hovering in
                    isHovering = hovering
                }
        }
        .menuStyle(.borderlessButton)
        .help("More options...")
    }

    // MARK: - Show Finder Get Info window (positioned near MiMi window)
    private func handleGetInfo() {
        guard let url = currentDirectoryURL else {
            log.warning("No directory selected for Get Info")
            return
        }
        log.info("Opening Get Info for: \(url.path)")
        FinderIntegration.showGetInfo(for: url)
    }

    // MARK: - Reveal in Finder
    private func handleOpenInFinder() {
        guard let url = currentDirectoryURL else {
            log.warning("No directory selected for Open in Finder")
            return
        }
        log.info("Opening in Finder: \(url.path)")
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
    
    // MARK: - Copy path to clipboard
    private func handleCopyPath() {
        guard let url = currentDirectoryURL else {
            log.warning("No directory selected for Copy Path")
            return
        }
        log.info("Copying path: \(url.path)")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.path, forType: .string)
    }
    
    // MARK: - Get current directory URL from focused panel
    private var currentDirectoryURL: URL? {
        appState.pathURL(for: appState.focusedPanel)
    }
}
