// AppToolbarContent.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 24.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Dynamic toolbar content driven by ToolbarStore.
//   SwiftUI's @ToolbarContentBuilder does not support ForEach with heterogeneous
//   ToolbarItem types, so each slot is declared explicitly with an `if` guard.
//   Visibility is checked against ToolbarStore.shared.visibleIDs.
//   Ordering is determined by ToolbarStore.shared.orderedIDs — the `if` guards
//   are evaluated in declaration order, which matches the default ordering.
//   When the user reorders, the NSToolbar system respects the saved item order
//   because each ToolbarItem has a stable id tied to ToolbarItemID.rawValue.

import SwiftUI

// MARK: - App Toolbar Content
/// Declares all 8 customisable toolbar slots.
/// Each slot is guarded by a visibility check so hidden items are omitted.
struct AppToolbarContent: ToolbarContent {

    /// Back-reference to the app struct so we can call its toolbar-item factory methods.
    let app: MiMiNavigatorApp

    private var store: ToolbarStore { ToolbarStore.shared }

    // MARK: - Body
    var body: some ToolbarContent {
        if store.visibleIDs.contains(.refresh) {
            app.toolBarItemRefresh()
        }
        if store.visibleIDs.contains(.hiddenFiles) {
            app.toolBarItemHidden()
        }
        if store.visibleIDs.contains(.openWith) {
            app.toolBarOpenWith()
        }
        if store.visibleIDs.contains(.swapPanels) {
            app.toolBarItemSwapPanels()
        }
        if store.visibleIDs.contains(.compare) {
            app.toolBarItemCompare()
        }
        if store.visibleIDs.contains(.network) {
            app.toolBarItemNetwork()
        }
        if store.visibleIDs.contains(.connectServer) {
            app.toolBarItemConnectToServer()
        }
        if store.visibleIDs.contains(.findFiles) {
            app.toolBarItemSearch()
        }
        if store.visibleIDs.contains(.settings) {
            app.toolBarItemSettings()
        }
        // menuBarToggle — fixed, always present, not removable
        app.toolBarItemMenuBarToggle()
    }
}
