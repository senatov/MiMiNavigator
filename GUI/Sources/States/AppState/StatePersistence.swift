// StatePersistence.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 27.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Save and restore app state to/from UserDefaults

import Foundation
import FileModelKit

// MARK: - State Persistence
/// Handles saving and restoring application state
@MainActor
enum StatePersistence {
    
    // MARK: - Save State
    
    /// Save current app state before exit
    static func saveBeforeExit(from state: AppState) {
        log.debug("[StatePersistence] saveBeforeExit")
        UserPreferences.shared.capture(from: state)
        let ud = MiMiDefaults.shared
        ud.set(state.leftPath, forKey: PreferenceKeys.leftPath.rawValue)
        ud.set(state.rightPath, forKey: PreferenceKeys.rightPath.rawValue)
        ud.set(state.focusedPanel == .left ? "left" : "right", forKey: PreferenceKeys.lastFocusedPanel.rawValue)
        if let left = state.selectedLeftFile?.urlValue {
            ud.set(left, forKey: PreferenceKeys.lastSelectedLeftFilePath.rawValue)
        }
        if let right = state.selectedRightFile?.urlValue {
            ud.set(right, forKey: PreferenceKeys.lastSelectedRightFilePath.rawValue)
        }
        if let leftTabData = state.leftTabManager.encodedTabs() {
            ud.set(leftTabData, forKey: PreferenceKeys.leftTabs.rawValue)
        }
        if let rightTabData = state.rightTabManager.encodedTabs() {
            ud.set(rightTabData, forKey: PreferenceKeys.rightTabs.rawValue)
        }
        ud.set(state.leftTabManager.activeTabIDString, forKey: PreferenceKeys.leftActiveTabID.rawValue)
        ud.set(state.rightTabManager.activeTabIDString, forKey: PreferenceKeys.rightActiveTabID.rawValue)
        ud.set(state.sortKey.rawValue, forKey: PreferenceKeys.sortKey.rawValue)
        ud.set(state.bSortAscending, forKey: PreferenceKeys.sortAscending.rawValue)
        log.info("[StatePersistence] state saved (tabs L=\(state.leftTabManager.tabs.count) R=\(state.rightTabManager.tabs.count), sort=\(state.sortKey.rawValue) asc=\(state.bSortAscending))")
    }
    
    // MARK: - Load Initial Paths
    
    /// Get initial URLs for panels (from UserDefaults or defaults).
    static func loadInitialPaths() -> (left: URL, right: URL) {
        let fm = FileManager.default
        let ud = MiMiDefaults.shared
        let defaultLeft = fm.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory())
        let defaultRight = fm.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: "/Users")
        let savedLeft = ud.string(forKey: PreferenceKeys.leftPath.rawValue)
        let savedRight = ud.string(forKey: PreferenceKeys.rightPath.rawValue)
        let leftURL = validDirectoryURL(savedLeft, fallback: defaultLeft)
        let rightURL = validDirectoryURL(savedRight, fallback: defaultRight)
        log.debug("[StatePersistence] loaded paths L=\(leftURL.path) R=\(rightURL.path)")
        return (leftURL, rightURL)
    }

    /// Returns URL for `path` if it points to an existing, accessible directory; otherwise `fallback`.
    private static func validDirectoryURL(_ path: String?, fallback: URL) -> URL {
        guard let path, !path.isEmpty else { return fallback }
        let url = URL(fileURLWithPath: path).resolvingSymlinksInPath()
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else {
            log.warning("[StatePersistence] saved path missing/not dir: \(url.path) → fallback \(fallback.path)")
            return fallback
        }
        if url.path.contains("/DerivedData/") || url.path.contains(".xcarchive") {
            log.warning("[StatePersistence] ephemeral path: \(url.path) → fallback \(fallback.path)")
            return fallback
        }
        return url
    }
    
    /// Get initial focused panel
    static func loadInitialFocus() -> PanelSide {
        let ud = MiMiDefaults.shared
        if let raw = ud.string(forKey: PreferenceKeys.lastFocusedPanel.rawValue), raw == "right" {
            return .right
        }
        return .left
    }
    
    // MARK: - Restore Tabs
    
    static func restoreTabs(into state: AppState) {
        let ud = MiMiDefaults.shared
        if let leftData = ud.data(forKey: PreferenceKeys.leftTabs.rawValue) {
            state.leftTabManager.restoreTabs(from: leftData)
            if let activeID = ud.string(forKey: PreferenceKeys.leftActiveTabID.rawValue) {
                state.leftTabManager.restoreActiveTabID(from: activeID)
            }
        }
        if let rightData = ud.data(forKey: PreferenceKeys.rightTabs.rawValue) {
            state.rightTabManager.restoreTabs(from: rightData)
            if let activeID = ud.string(forKey: PreferenceKeys.rightActiveTabID.rawValue) {
                state.rightTabManager.restoreActiveTabID(from: activeID)
            }
        }
        log.info("[StatePersistence] tabs restored L=\(state.leftTabManager.tabs.count) R=\(state.rightTabManager.tabs.count)")
    }
    
    // MARK: - Restore Sorting
    
    static func restoreSorting(into state: AppState) {
        let ud = MiMiDefaults.shared
        if let sortKeyRaw = ud.string(forKey: PreferenceKeys.sortKey.rawValue),
           let sortKey = SortKeysEnum(rawValue: sortKeyRaw) {
            state.sortKey = sortKey
        }
        if ud.object(forKey: PreferenceKeys.sortAscending.rawValue) != nil {
            state.bSortAscending = ud.bool(forKey: PreferenceKeys.sortAscending.rawValue)
        }
        log.debug("[StatePersistence] sorting restored: key=\(state.sortKey.rawValue) asc=\(state.bSortAscending)")
    }
}
