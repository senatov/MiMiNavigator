// TableColumnConfig.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 27.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Column configuration constants and constraints for FileTableView

import SwiftUI

// MARK: - Column Defaults
/// Default constraints and padding for resizable columns
enum TableColumnDefaults {
    // Universal min/max for all columns
    static let minWidth: CGFloat = 40
    static let maxWidth: CGFloat = 200

    /// Horizontal padding applied INSIDE each fixed column cell (header AND row must use same value)
    static let cellPadding: CGFloat = 6
}

// MARK: - Column Constraints
/// Min/max constraints for column resizing (per-column specific)
enum TableColumnConstraints {
    static let sizeMin: CGFloat = 30
    static let sizeMax: CGFloat = 120
    static let dateMin: CGFloat = 80
    static let dateMax: CGFloat = 160
    static let typeMin: CGFloat = 50
    static let typeMax: CGFloat = 120
    static let permissionsMin: CGFloat = 60
    static let permissionsMax: CGFloat = 100
    static let ownerMin: CGFloat = 50
    static let ownerMax: CGFloat = 120
}

// MARK: - Header Style
/// Visual styling for column headers
enum TableHeaderStyle {
    /// SF Pro Display Thin 14 — as requested
    static let font = Font.custom("SF Pro Display", size: 14).weight(.thin)
    /// Dark navy blue for inactive column titles
    static let color = Color(#colorLiteral(red: 0.08, green: 0.15, blue: 0.40, alpha: 1.0))
    /// Dark purple for active sort column title + chevron
    static let sortIndicatorColor = Color(#colorLiteral(red: 0.35, green: 0.05, blue: 0.55, alpha: 1.0))
    /// Active sort column title weight
    static let sortActiveWeight: Font.Weight = .medium
    /// Very light yellow tint for active sort column background
    static let activeSortBackground = Color(#colorLiteral(red: 1.0, green: 0.95, blue: 0.7, alpha: 0.35))
    static let backgroundColor = Color(nsColor: .controlBackgroundColor)
    static let separatorColor = Color(nsColor: .separatorColor)
}

// MARK: - Column Separator Style
/// Visual styling for column separators (both header and rows)
enum ColumnSeparatorStyle {
    /// Dark navy blue for passive divider line (matches header text)
    static let color = Color(#colorLiteral(red: 0.08, green: 0.15, blue: 0.40, alpha: 1.0)).opacity(0.45)
    /// Light blue on cursor hover (stays blue)
    static let hoverColor = Color(#colorLiteral(red: 0.35, green: 0.65, blue: 1.0, alpha: 1.0)).opacity(0.80)
    /// Bright blue while dragging (stays blue)
    static let dragColor = Color(#colorLiteral(red: 0.20, green: 0.50, blue: 1.0, alpha: 1.0)).opacity(0.90)
    /// Passive line width — 1pt ensures visibility at all display scales
    static let width: CGFloat = 1.0
    /// Active (hover/drag) line width
    static let activeWidth: CGFloat = 2.0
}

// MARK: - Column Separator
/// Simple vertical separator between columns (non-resizable)
struct ColumnSeparator: View {
    var body: some View {
        Rectangle()
            .fill(ColumnSeparatorStyle.color)
            .frame(width: ColumnSeparatorStyle.width)
            .allowsHitTesting(false)
    }
}
