// GeoTagBadgeCellHelper.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 10.05.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: AppKit table-cell badge overlay for geo-tagged pictures.

import AppKit

private let geoTagBadgeIdentifier = NSUserInterfaceItemIdentifier("GeoTagBadge")
private let geoTagBadgeColor = NSColor(#colorLiteral(red: 0.9490196078, green: 0.3960784314, blue: 0.1333333333, alpha: 1))
private let geoTagBadgeSize: CGFloat = 7

// MARK: - Geo-tag badge cell helper
@MainActor
enum GeoTagBadgeCellHelper {

    // MARK: - Ensure badge view
    static func ensureBadgeView(in cell: NSTableCellView) {
        guard badgeView(in: cell) == nil, let iconView = cell.imageView else {
            configureBadgeView(in: cell)
            return
        }
        let badge = NSImageView()
        badge.identifier = geoTagBadgeIdentifier
        badge.translatesAutoresizingMaskIntoConstraints = false
        badge.imageScaling = .scaleProportionallyUpOrDown
        cell.addSubview(badge)
        NSLayoutConstraint.activate([
            badge.widthAnchor.constraint(equalToConstant: geoTagBadgeSize),
            badge.heightAnchor.constraint(equalToConstant: geoTagBadgeSize),
            badge.trailingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 2),
            badge.bottomAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 2),
        ])
        configure(badge)
    }

    // MARK: - Update badge visibility
    static func updateBadge(in cell: NSTableCellView, isVisible: Bool) {
        configureBadgeView(in: cell)
        badgeView(in: cell)?.isHidden = !isVisible
    }

    // MARK: - Configure badge in cell
    private static func configureBadgeView(in cell: NSTableCellView) {
        guard let badge = badgeView(in: cell) as? NSImageView else { return }
        configure(badge)
    }

    // MARK: - Configure badge image
    private static func configure(_ badge: NSImageView) {
        badge.image = makeBadgeImage()
        badge.contentTintColor = nil
        badge.symbolConfiguration = nil
    }

    // MARK: - Badge image
    private static func makeBadgeImage() -> NSImage {
        let image = NSImage(size: NSSize(width: geoTagBadgeSize, height: geoTagBadgeSize))
        image.lockFocus()
        geoTagBadgeColor.setFill()
        NSBezierPath(ovalIn: NSRect(x: 0.5, y: 0.5, width: geoTagBadgeSize - 1, height: geoTagBadgeSize - 1)).fill()
        NSColor.white.setStroke()
        let path = NSBezierPath()
        path.lineWidth = 0.7
        path.move(to: NSPoint(x: 1.7, y: 3.5))
        path.curve(to: NSPoint(x: 5.3, y: 3.5), controlPoint1: NSPoint(x: 2.6, y: 4.7), controlPoint2: NSPoint(x: 4.4, y: 4.7))
        path.move(to: NSPoint(x: 1.7, y: 3.5))
        path.curve(to: NSPoint(x: 5.3, y: 3.5), controlPoint1: NSPoint(x: 2.6, y: 2.3), controlPoint2: NSPoint(x: 4.4, y: 2.3))
        path.move(to: NSPoint(x: 3.5, y: 1.4))
        path.curve(to: NSPoint(x: 3.5, y: 5.6), controlPoint1: NSPoint(x: 2.8, y: 2.2), controlPoint2: NSPoint(x: 2.8, y: 4.8))
        path.move(to: NSPoint(x: 3.5, y: 1.4))
        path.curve(to: NSPoint(x: 3.5, y: 5.6), controlPoint1: NSPoint(x: 4.2, y: 2.2), controlPoint2: NSPoint(x: 4.2, y: 4.8))
        path.stroke()
        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    // MARK: - Badge lookup
    private static func badgeView(in cell: NSTableCellView) -> NSView? {
        cell.subviews.first { $0.identifier == geoTagBadgeIdentifier }
    }
}
