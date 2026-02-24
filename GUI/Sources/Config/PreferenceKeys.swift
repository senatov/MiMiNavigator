// PreferenceKeys.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 23.10.2024.
// Copyright © 2024-2026 Senatov. All rights reserved.
// Description: Centralized UserDefaults keys for application preferences and state persistence

import Foundation
import FileModelKit

// MARK: - Preference Keys
/// Centralized storage for all UserDefaults keys used in the app.
/// Use with `UserDefaults.standard.string(forKey: PreferenceKeys.leftPath.rawValue)`
enum PreferenceKeys: String, CaseIterable {
    // MARK: - Panel Paths
    case leftPath = "lastLeftPath"
    case rightPath = "lastRightPath"
    
    // MARK: - Focus State
    case lastFocusedPanel
    
    // MARK: - Display Settings
    case showHiddenFiles
    
    // MARK: - Favorites Settings
    case favoritesMaxDepth
    case expandedFolders
    
    // MARK: - Selection State
    case lastSelectedLeftFilePath
    case lastSelectedRightFilePath
    
    // MARK: - Tab State
    case leftTabs
    case rightTabs
    case leftActiveTabID
    case rightActiveTabID
    
    // MARK: - Column Widths Helper
    /// Generates key for column width storage
    static func columnWidth(for column: String, panel: PanelSide) -> String {
        "FileTable.\(panel).\(column)Width"
    }
}
