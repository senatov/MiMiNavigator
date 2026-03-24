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

    // MARK: - Panels
    var showIcons: Bool
    var calculateSizes: Bool
    var highlightBorder: Bool
    var defaultSort: String              // "name", "date", "size", "type"
    var sortAscending: Bool
    var dateFormat: String               // "short", "medium", "relative", "iso"
    var showSizeInKB: Bool
    var openOnSingleClick: Bool
    var rowDensity: String               // "compact", "normal", "spacious"

    // MARK: - Tabs
    var tabsRestoreOnLaunch: Bool
    var tabsOpenFolderInNewTab: Bool
    var tabsCloseLastKeepsPanel: Bool
    var tabsPosition: String             // "top", "bottom"
    var tabsShowCloseButton: Bool
    var tabsMaxTabs: Double
    var tabsSortByName: Bool

    // MARK: - Archives
    var archiveDefaultFormat: String     // "zip", "tar.gz", "tar.bz2", etc.
    var archiveCompressionLevel: Double
    var archiveExtractToSubfolder: Bool
    var archiveShowExtractProgress: Bool
    var archiveOpenOnDoubleClick: Bool
    var archiveConfirmOnModified: Bool
    var archiveAutoRepack: Bool

    // MARK: - Network
    var networkTimeoutSec: Double
    var networkRetryCount: Double
    var networkSavePasswords: Bool
    var networkShowInSidebar: Bool
    var networkAutoReconnect: Bool

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
        // Panels
        showIcons: true,
        calculateSizes: false,
        highlightBorder: true,
        defaultSort: "name",
        sortAscending: true,
        dateFormat: "short",
        showSizeInKB: false,
        openOnSingleClick: false,
        rowDensity: "normal",
        // Tabs
        tabsRestoreOnLaunch: true,
        tabsOpenFolderInNewTab: false,
        tabsCloseLastKeepsPanel: true,
        tabsPosition: "top",
        tabsShowCloseButton: true,
        tabsMaxTabs: 32,
        tabsSortByName: false,
        // Archives
        archiveDefaultFormat: "zip",
        archiveCompressionLevel: 6,
        archiveExtractToSubfolder: true,
        archiveShowExtractProgress: true,
        archiveOpenOnDoubleClick: true,
        archiveConfirmOnModified: true,
        archiveAutoRepack: true,
        // Network
        networkTimeoutSec: 15,
        networkRetryCount: 3,
        networkSavePasswords: true,
        networkShowInSidebar: true,
        networkAutoReconnect: false,
        // Favorites
        favoritesMaxDepth: 2,
        expandedFolders: []
    )
}
