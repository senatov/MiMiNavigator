// GeoTagBadgeCellHelper.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 10.05.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: AppKit table-cell badge overlay for geo-tagged pictures.

import AppKit

private let geoTagBadgeIdentifier = NSUserInterfaceItemIdentifier("GeoTagBadge")

// MARK: - Geo-tag badge cell helper
@MainActor
enum GeoTagBadgeCellHelper {

    // MARK: - Ensure badge view
    static func ensureBadgeView(in cell: NSTableCellView) {
        guard badgeView(in: cell) == nil, let iconView = cell.imageView else { return }
        let badge = NSImageView()
        badge.identifier = geoTagBadgeIdentifier
        badge.translatesAutoresizingMaskIntoConstraints = false
        badge.imageScaling = .scaleProportionallyUpOrDown
        badge.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 8, weight: .bold)
        badge.contentTintColor = NSColor(#colorLiteral(red: 0.2392156869, green: 0.6745098233, blue: 0.9686274529, alpha: 1))
        badge.image = NSImage(systemSymbolName: "globe.europe.africa.fill", accessibilityDescription: nil)
        cell.addSubview(badge)
        NSLayoutConstraint.activate([
            badge.widthAnchor.constraint(equalToConstant: 9),
            badge.heightAnchor.constraint(equalToConstant: 9),
            badge.trailingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 2),
            badge.bottomAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 2),
        ])
    }

    // MARK: - Update badge visibility
    static func updateBadge(in cell: NSTableCellView, isVisible: Bool) {
        badgeView(in: cell)?.isHidden = !isVisible
    }

    // MARK: - Badge lookup
    private static func badgeView(in cell: NSTableCellView) -> NSView? {
        cell.subviews.first { $0.identifier == geoTagBadgeIdentifier }
    }
}
