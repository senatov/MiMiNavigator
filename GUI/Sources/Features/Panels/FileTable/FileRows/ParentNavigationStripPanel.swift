// ParentNavigationStripPanel.swift
// MiMiNavigator
//
// Created by Claude on 22.04.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Fixed panel above file table showing ".." parent-navigation strip.
//   Lives outside ScrollView — not part of file rows, not selectable via context menu,
//   not participating in keyboard row navigation. Activates parent dir on click/dblclick.
//   Visual appearance identical to the old in-table ParentEntryStripView.

import FileModelKit
import SwiftUI

// MARK: - ParentNavigationStripPanel

/// Fixed panel placed above the file table ScrollView.
/// Shows parent directory path with pebble button; click navigates up.
/// Not a file row — has no context menu, no row selection, no keyboard nav index.
struct ParentNavigationStripPanel: View {
    @Environment(AppState.self) private var appState

    let panelSide: FavPanelSide
    let isHighlighted: Bool
    let onSelect: (CustomFile) -> Void
    let onActivate: (CustomFile) -> Void


    private var currentPath: String {
        appState.path(for: panelSide)
    }

    private var remoteURL: URL? {
        guard let url = URL(string: currentPath), AppState.isRemotePath(url) else { return nil }
        return url
    }

    private var remotePath: String {
        guard let remoteURL else { return "/" }
        return remoteURL.path.isEmpty ? "/" : remoteURL.path
    }

    private var shouldShow: Bool {
        if remoteURL != nil {
            return remotePath != "/"
        }
        return currentPath != "/"
    }

    private var parentPath: String {
        if remoteURL != nil {
            let parent = (remotePath as NSString).deletingLastPathComponent
            return parent.isEmpty ? "/" : parent
        }
        return (currentPath as NSString).deletingLastPathComponent
    }

    private var parentFile: CustomFile {
        CustomFile(name: "..", path: parentPath, children: nil, isParentEntry: true)
    }


    private var parentURL: URL {
        parentFile.urlValue
    }


    var body: some View {
        if shouldShow {
            ParentEntryStripView(
                file: parentFile,
                isSelected: isHighlighted,
                parentURL: parentURL,
                onSelect: onSelect,
                onActivate: activateParent
            )
        }
    }

    // MARK: - Activation
    private func activateParent(_ file: CustomFile) {
        if remoteURL != nil {
            Task { @MainActor in
                await appState.navigateToParent(on: panelSide)
            }
            return
        }
        onActivate(file)
    }
}
