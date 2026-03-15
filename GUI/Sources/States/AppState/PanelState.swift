// PanelState.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 15.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Encapsulates ALL state belonging to a single file panel.
//              Eliminates left/right property duplication in AppState.

import FileModelKit
import Foundation

// MARK: - PanelState
struct PanelState {

    /// Current directory URL
    var currentDirectory: URL

    /// Currently selected file
    var selectedFile: CustomFile?

    // MARK: - Filter
    var filterQuery: String = ""

    // MARK: - Marks (Total Commander style)
    var markedFiles: Set<String> = []

    // MARK: - Index tracking
    var selectedIndex: Int = 0
    var visibleIndex: Int = 0

    // MARK: - Archive
    var archiveState = ArchiveNavigationState()

    // MARK: - Search Results
    var searchResultsPath: String?

    // MARK: - Version counter for change detection
    var filesVersion: Int = 0

    // MARK: - Saved local URL (before remote connection)
    var savedLocalURL: URL?

    // MARK: - Navigation history (legacy bridge)
    var navigationHistory: PanelNavigationHistory?
}
