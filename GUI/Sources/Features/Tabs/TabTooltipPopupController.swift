// TabTooltipPopupController.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Yellow HUD popup for panel tab hover details.

import AppKit
import FileModelKit
import Foundation

// MARK: - Tab Tooltip Popup Controller
@MainActor
final class TabTooltipPopupController: InfoPopupController {

    static let shared = TabTooltipPopupController()

    private override init() {
        super.init()
    }

    // MARK: - Show Tab Info
    func show(tab: TabItem, panelSide: FavPanelSide, isActive: Bool, anchorFrame: CGRect) {
        show(content: buildContent(tab: tab, panelSide: panelSide, isActive: isActive), anchorFrame: anchorFrame, width: 390)
    }

    // MARK: - Build Content
    private func buildContent(tab: TabItem, panelSide: FavPanelSide, isActive: Bool) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let title = tab.isArchive ? "Archive Tab" : "Folder Tab"
        result.appendHUD(
            "\(title)\n",
            font: NSFont.systemFont(ofSize: 13.5, weight: .medium),
            color: InfoPopupController.titleColor
        )
        result.appendHUD(
            "\(tab.displayName)\n\n",
            font: NSFont.systemFont(ofSize: 13, weight: .regular),
            color: InfoPopupController.valueColor
        )
        result.appendField(label: "Panel", value: panelSide == .left ? "Left" : "Right")
        result.appendField(label: "State", value: isActive ? "Active" : "Inactive")
        result.appendField(label: "Path", value: tab.url.path)
        if let archiveURL = tab.archiveURL {
            result.appendField(label: "Archive", value: archiveURL.path)
        }
        result.appendHUD(
            "\nClick to activate. Hover the close button to close this tab.",
            font: NSFont.systemFont(ofSize: 10.5, weight: .regular),
            color: NSColor.secondaryLabelColor
        )
        return result
    }
}
