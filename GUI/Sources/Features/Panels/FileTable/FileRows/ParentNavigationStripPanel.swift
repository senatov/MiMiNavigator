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


    private var shouldShow: Bool {
        currentPath != "/"
    }


    private var parentFile: CustomFile {
        CustomFile.parentLink(from: currentPath)
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
                onActivate: onActivate
            )
        }
    }
}
