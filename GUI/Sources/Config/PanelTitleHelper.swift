// PanelTitleHelper.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Applies a visible native macOS title to standalone NSPanel windows.

import AppKit

// MARK: - PanelTitleHelper
@MainActor
enum PanelTitleHelper {

    // MARK: - applyIconTitle
    /// Applies the native macOS title used by all standalone panels.
    /// - Parameters:
    ///   - panel: The NSPanel to decorate.
    ///   - systemImage: SF Symbol name (must match the toolbar button icon).
    ///   - title: The dialog title text.
    static func applyIconTitle(to panel: NSPanel, systemImage: String, title: String) {
        panel.title = title
        removeExistingAccessories(from: panel)
        panel.titleVisibility = .visible
    }


    private static func removeExistingAccessories(from panel: NSPanel) {
        while !panel.titlebarAccessoryViewControllers.isEmpty {
            panel.removeTitlebarAccessoryViewController(at: 0)
        }
    }
}
