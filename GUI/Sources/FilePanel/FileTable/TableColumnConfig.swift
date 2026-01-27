// TableColumnConfig.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 27.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Column configuration constants and constraints for FileTableView

import SwiftUI

// MARK: - Column Defaults
/// Default widths for resizable columns
enum TableColumnDefaults {
    static let size: CGFloat = 65
    static let date: CGFloat = 115
    static let type: CGFloat = 50
}

// MARK: - Column Constraints
/// Min/max constraints for column resizing
enum TableColumnConstraints {
    static let sizeMin: CGFloat = 30
    static let sizeMax: CGFloat = 120
    static let dateMin: CGFloat = 30
    static let dateMax: CGFloat = 180
    static let typeMin: CGFloat = 30
    static let typeMax: CGFloat = 100
}

// MARK: - Header Style
/// Visual styling for column headers
enum TableHeaderStyle {
    static let font = Font.system(size: 12, weight: .semibold, design: .default)
    static let color = Color(red: 0.1, green: 0.2, blue: 0.45)
}

// MARK: - Column Width Storage
/// Handles persistence of column widths per panel
struct ColumnWidthStorage {
    let panelSide: PanelSide
    
    var sizeWidthKey: String { "FileTable.\(panelSide).sizeWidth" }
    var dateWidthKey: String { "FileTable.\(panelSide).dateWidth" }
    var typeWidthKey: String { "FileTable.\(panelSide).typeWidth" }
    
    func load() -> (size: CGFloat, date: CGFloat, type: CGFloat) {
        let defaults = UserDefaults.standard
        let size = (defaults.object(forKey: sizeWidthKey) as? CGFloat) ?? TableColumnDefaults.size
        let date = (defaults.object(forKey: dateWidthKey) as? CGFloat) ?? TableColumnDefaults.date
        let type = (defaults.object(forKey: typeWidthKey) as? CGFloat) ?? TableColumnDefaults.type
        
        log.debug("[ColumnWidthStorage] loaded \(panelSide): size=\(size) date=\(date) type=\(type)")
        return (size > 0 ? size : TableColumnDefaults.size,
                date > 0 ? date : TableColumnDefaults.date,
                type > 0 ? type : TableColumnDefaults.type)
    }
    
    func save(size: CGFloat, date: CGFloat, type: CGFloat) {
        let defaults = UserDefaults.standard
        defaults.set(size, forKey: sizeWidthKey)
        defaults.set(date, forKey: dateWidthKey)
        defaults.set(type, forKey: typeWidthKey)
        log.debug("[ColumnWidthStorage] saved \(panelSide): size=\(size) date=\(date) type=\(type)")
    }
}
