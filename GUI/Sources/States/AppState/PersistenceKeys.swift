// PersistenceKeys.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 27.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Centralized UserDefaults keys for app state persistence

import Foundation

// MARK: - Persistence Keys
/// Centralized storage for all UserDefaults keys used in the app
enum PersistenceKeys {
    // Panel paths
    static let lastLeftPath = "lastLeftPath"
    static let lastRightPath = "lastRightPath"
    
    // Focus state
    static let lastFocusedPanel = "lastFocusedPanel"
    
    // Selections
    static let lastSelectedLeftFilePath = "lastSelectedLeftFilePath"
    static let lastSelectedRightFilePath = "lastSelectedRightFilePath"
    
    // Column widths (template, panel side appended)
    static func columnWidth(for column: String, panel: PanelSide) -> String {
        "FileTable.\(panel).\(column)Width"
    }
}
