// PanelNavigationCallbacks.swift
// MiMiNavigator
//
// Created by Claude on 08.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Navigation callback container for keyboard-driven file panel navigation.
//              Registered by FileTableView, invoked by DuoFilePanelKeyboardHandler via AppState.

import Foundation

// MARK: - Panel Navigation Callbacks
/// Holds closures for all keyboard navigation actions on a single panel.
/// FileTableView registers these on appear; DuoFilePanelKeyboardHandler
/// dispatches arrow/PgUp/PgDown/Home/End through AppState.navigationCallbacks.
@MainActor
struct PanelNavigationCallbacks {
    var moveUp: () -> Void = {}
    var moveDown: () -> Void = {}
    var pageUp: () -> Void = {}
    var pageDown: () -> Void = {}
    var jumpToFirst: () -> Void = {}
    var jumpToLast: () -> Void = {}
    /// Scroll to a file by name (used after rename/create to ensure visibility)
    var scrollToName: (String) -> Void = { _ in }
}
