// PanelTitleHelper.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Adds a dark-blue SF Symbol icon before the standard NSPanel title.
//   The icon matches the toolbar button that opened the dialog (HIG 26 convention).
//   Uses NSTitlebarAccessoryViewController with a SwiftUI HStack(Image + Text).
//   Native panel.title kept for Mission Control / Dock / window list.

import AppKit
import SwiftUI

// MARK: - PanelTitleHelper
@MainActor
enum PanelTitleHelper {

    /// Dark navy blue used for the leading icon in dialog titles.
    private static let iconColor = NSColor(red: 0.10, green: 0.15, blue: 0.55, alpha: 1.0)

    // MARK: - applyIconTitle
    /// Replaces the standard `panel.title` with a custom titlebar accessory
    /// showing `SF Symbol (dark blue)  Title`.
    /// - Parameters:
    ///   - panel: The NSPanel to decorate.
    ///   - systemImage: SF Symbol name (must match the toolbar button icon).
    ///   - title: The dialog title text.
    static func applyIconTitle(to panel: NSPanel, systemImage: String, title: String) {
        // Keep native title for Mission Control / Dock / window list
        panel.title = title
        // Build the SwiftUI accessory view
        let titleView = NSHostingView(
            rootView: HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .light))
                    .foregroundColor(Color(nsColor: iconColor))
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
            }
            .padding(.leading, 8)
            .frame(height: 22)
        )
        let accessory = NSTitlebarAccessoryViewController()
        accessory.view = titleView
        accessory.layoutAttribute = .leading
        // Remove any previously added accessories (idempotent)
        while !panel.titlebarAccessoryViewControllers.isEmpty {
            panel.removeTitlebarAccessoryViewController(at: 0)
        }
        panel.addTitlebarAccessoryViewController(accessory)
        // Hide the native title text so it doesn't duplicate
        panel.titleVisibility = .hidden
    }
}
