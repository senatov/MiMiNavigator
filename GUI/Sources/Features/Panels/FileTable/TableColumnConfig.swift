// TableColumnConfig.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 27.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Column configuration constants and constraints for FileTableView

import SwiftUI

// MARK: - Column Defaults
/// Default widths for resizable columns (Finder-style)
enum TableColumnDefaults {
    static let size: CGFloat = 70
    static let date: CGFloat = 120
    static let type: CGFloat = 80
    static let permissions: CGFloat = 75
    static let owner: CGFloat = 70

    // Universal min/max for all columns
    static let minWidth: CGFloat = 40
    static let maxWidth: CGFloat = 200
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
/// Visual styling for column headers (bold, clear, Finder-style)
enum TableHeaderStyle {
    static let font = Font.system(size: 12, weight: .semibold)
    static let color = Color.primary
    static let sortIndicatorColor = Color.accentColor
    /// Very light yellow background for active sort column
    static let activeSortBackground = Color(#colorLiteral(red: 1.0, green: 0.95, blue: 0.7, alpha: 0.35))
    static let backgroundColor = Color(nsColor: .controlBackgroundColor)
    static let separatorColor = Color(nsColor: .separatorColor)
}

// MARK: - Column Separator Style
/// Visual styling for column separators (both header and rows)
enum ColumnSeparatorStyle {
    /// Pale orange for passive column divider
    static let color = Color(#colorLiteral(red: 1.0, green: 0.72, blue: 0.45, alpha: 1.0)).opacity(0.40)
    /// Pale blue on cursor hover
    static let hoverColor = Color(#colorLiteral(red: 0.35, green: 0.65, blue: 1.0, alpha: 1.0)).opacity(0.80)
    /// Red-orange while dragging
    static let dragColor = Color(#colorLiteral(red: 0.95, green: 0.38, blue: 0.10, alpha: 1.0)).opacity(0.90)
    /// Passive line width
    static let width: CGFloat = 0.5
    /// Active (hover/drag) line width
    static let activeWidth: CGFloat = 1.0
}

// MARK: - Column Width Storage
/// Handles persistence of column widths per panel
struct ColumnWidthStorage {
    let panelSide: PanelSide

    var sizeWidthKey: String { "FileTable.\(panelSide).sizeWidth" }
    var dateWidthKey: String { "FileTable.\(panelSide).dateWidth" }
    var typeWidthKey: String { "FileTable.\(panelSide).typeWidth" }
    var permissionsWidthKey: String { "FileTable.\(panelSide).permissionsWidth" }
    var ownerWidthKey: String { "FileTable.\(panelSide).ownerWidth" }

    func load() -> (size: CGFloat, date: CGFloat, type: CGFloat, permissions: CGFloat, owner: CGFloat) {
        let defaults = UserDefaults.standard
        let size = (defaults.object(forKey: sizeWidthKey) as? CGFloat) ?? TableColumnDefaults.size
        let date = (defaults.object(forKey: dateWidthKey) as? CGFloat) ?? TableColumnDefaults.date
        let type = (defaults.object(forKey: typeWidthKey) as? CGFloat) ?? TableColumnDefaults.type
        let permissions = (defaults.object(forKey: permissionsWidthKey) as? CGFloat) ?? TableColumnDefaults.permissions
        let owner = (defaults.object(forKey: ownerWidthKey) as? CGFloat) ?? TableColumnDefaults.owner

        log.debug("[ColumnWidthStorage] loaded \(panelSide): size=\(size) date=\(date) type=\(type) perm=\(permissions) owner=\(owner)")
        return (size > 0 ? size : TableColumnDefaults.size,
                date > 0 ? date : TableColumnDefaults.date,
                type > 0 ? type : TableColumnDefaults.type,
                permissions > 0 ? permissions : TableColumnDefaults.permissions,
                owner > 0 ? owner : TableColumnDefaults.owner)
    }

    func save(size: CGFloat, date: CGFloat, type: CGFloat, permissions: CGFloat, owner: CGFloat) {
        let defaults = UserDefaults.standard
        defaults.set(size, forKey: sizeWidthKey)
        defaults.set(date, forKey: dateWidthKey)
        defaults.set(type, forKey: typeWidthKey)
        defaults.set(permissions, forKey: permissionsWidthKey)
        defaults.set(owner, forKey: ownerWidthKey)
        log.debug("[ColumnWidthStorage] saved \(panelSide): size=\(size) date=\(date) type=\(type) perm=\(permissions) owner=\(owner)")
    }
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
