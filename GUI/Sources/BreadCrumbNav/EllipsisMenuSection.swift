//
//  EllipsisMenuSection.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 20.03.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import AppKit
import FileModelKit
import SwiftUI

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
        .focusable(false)
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
