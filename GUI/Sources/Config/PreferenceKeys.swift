// PreferenceKeys.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 23.10.2024.
// Refactored: 27.01.2026
// Copyright © 2024-2026 Senatov. All rights reserved.
// Description: UserDefaults keys for application preferences

import Foundation

// MARK: - Preference Keys
/// Keys used for storing user preferences in UserDefaults.
/// Use with `UserDefaults.standard.string(forKey: PreferenceKeys.leftPath.rawValue)`
enum PreferenceKeys: String, CaseIterable {
    // MARK: - Panel Paths
    case leftPath
    case rightPath
    
    // MARK: - Display Settings
    case showHiddenFiles
    
    // MARK: - Favorites Settings
    case favoritesMaxDepth
    case expandedFolders
    
    // MARK: - Selection State
    case lastSelectedLeftFilePath
    case lastSelectedRightFilePath
}

// MARK: - Deprecated Typealias (for backward compatibility)
typealias PrefKey = PreferenceKeys
