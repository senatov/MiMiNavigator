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
    private enum Constants {
        static let iconSpacing: CGFloat = 6
        static let leadingPadding: CGFloat = 8
        static let titleHeight: CGFloat = 22
        static let iconFontSize: CGFloat = 13
        static let titleFontSize: CGFloat = 13
    }

    // MARK: - applyIconTitle
    /// Replaces the standard `panel.title` with a custom titlebar accessory
    /// showing `SF Symbol (dark blue)  Title`.
    /// - Parameters:
    ///   - panel: The NSPanel to decorate.
    ///   - systemImage: SF Symbol name (must match the toolbar button icon).
    ///   - title: The dialog title text.
    static func applyIconTitle(to panel: NSPanel, systemImage: String, title: String) {
        panel.title = title
        removeExistingAccessories(from: panel)
        let titleView = makeTitleView(systemImage: systemImage, title: title)
        let accessory = NSTitlebarAccessoryViewController()
        accessory.view = titleView
        accessory.layoutAttribute = .leading
        panel.addTitlebarAccessoryViewController(accessory)
        panel.titleVisibility = .hidden
    }


    private static func makeTitleView(systemImage: String, title: String) -> NSHostingView<some View> {
        NSHostingView(
            rootView: HStack(spacing: Constants.iconSpacing) {
                Image(systemName: systemImage)
                    .font(.system(size: Constants.iconFontSize, weight: .light))
                    .foregroundColor(Color(nsColor: iconColor))
                Text(title)
                    .font(.system(size: Constants.titleFontSize, weight: .medium))
                    .foregroundStyle(.primary)
            }
            .padding(.leading, Constants.leadingPadding)
            .frame(height: Constants.titleHeight)
        )
    }


    private static func removeExistingAccessories(from panel: NSPanel) {
        while !panel.titlebarAccessoryViewControllers.isEmpty {
            panel.removeTitlebarAccessoryViewController(at: 0)
        }
    }
}
