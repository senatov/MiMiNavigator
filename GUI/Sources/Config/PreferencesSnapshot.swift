// PreferencesSnapshot.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 23.10.2024.
//  Copyright © 2024 Senatov. All rights reserved.
//

import Foundation

struct PreferencesSnapshot: Codable, Sendable {

    // MARK: - Panel paths
    var leftPath: String
    var rightPath: String
    var lastSelectedLeftFilePath: String?
    var lastSelectedRightFilePath: String?

    // MARK: - Display
    var appearance: String          // "system", "light", "dark"
    var panelFontSize: Double
    var iconSize: String            // "small", "medium", "large"
    var showHiddenFiles: Bool
    var showExtensions: Bool
    var autoFitColumnsOnNavigate: Bool

    // MARK: - Startup
    var startupPath: String         // "home", "last", "desktop", "downloads"

    // MARK: - Favorites
    var favoritesMaxDepth: Int
    var expandedFolders: Set<String>

    // MARK: - Default
    static let `default` = PreferencesSnapshot(
        leftPath: FileManager.default
            .urls(for: .downloadsDirectory, in: .userDomainMask)
            .first?
            .path ?? "/",
        rightPath: "/Users",
        lastSelectedLeftFilePath: nil,
        lastSelectedRightFilePath: nil,
        appearance: "system",
        panelFontSize: 14,
        iconSize: "medium",
        showHiddenFiles: false,
        showExtensions: true,
        autoFitColumnsOnNavigate: false,
        startupPath: "home",
        favoritesMaxDepth: 2,
        expandedFolders: []
    )
}
