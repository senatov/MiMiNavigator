//
//  FileTableRowView.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 13.03.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//  Description: Custom NSTableRowView for file panel — themed zebra stripe and selection drawing.
//               Extracted from NSFileTableView.swift.

import AppKit

// MARK: - Row View
final class FileTableRowView: NSTableRowView {
    var isFocused = false
    var colorStore: ColorThemeStore?
    var rowIndex = 0

    override func drawBackground(in dirtyRect: NSRect) {
        let theme = colorStore?.activeTheme ?? ColorTheme.defaultTheme
        let base = isFocused ? NSColor(theme.warmWhite) : NSColor.controlBackgroundColor
        let stripe = base.blended(withFraction: 0.03, of: .black) ?? base
        ((rowIndex % 2 == 0) ? base : stripe).setFill()
        bounds.fill()

    }
    override func drawSelection(in dirtyRect: NSRect) {
        guard selectionHighlightStyle != .none else { return }
        let theme = colorStore?.activeTheme ?? ColorTheme.defaultTheme

        // Fill background only
        let fillColor = isFocused ? NSColor(theme.selectionActive) : NSColor(theme.selectionInactive)
        fillColor.setFill()
        bounds.fill()

        // Draw borders
        let borderColor = isFocused ? NSColor(theme.selectionBorder) : NSColor.gray
        borderColor.setFill()
        let h = max(theme.selectionLineWidth, 2.0)
        NSRect(x: 0, y: bounds.height - h, width: bounds.width, height: h).fill()
        NSRect(x: 0, y: 0, width: bounds.width, height: h).fill()

    }
}
