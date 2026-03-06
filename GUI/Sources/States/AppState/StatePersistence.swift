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
        
        // Save user preferences (capture triggers save() via didSet — no explicit save needed)
        UserPreferences.shared.capture(from: state)
        
        let ud = UserDefaults.standard
        
        // Save panel paths
        ud.set(state.leftPath, forKey: PreferenceKeys.leftPath.rawValue)
        ud.set(state.rightPath, forKey: PreferenceKeys.rightPath.rawValue)
        
        // Save focus
        ud.set(state.focusedPanel == .left ? "left" : "right", forKey: PreferenceKeys.lastFocusedPanel.rawValue)
        
        // Save selections
        if let left = state.selectedLeftFile?.urlValue {
            ud.set(left, forKey: PreferenceKeys.lastSelectedLeftFilePath.rawValue)
        }
        if let right = state.selectedRightFile?.urlValue {
            ud.set(right, forKey: PreferenceKeys.lastSelectedRightFilePath.rawValue)
        }
        
        // Save tabs
        if let leftTabData = state.leftTabManager.encodedTabs() {
            ud.set(leftTabData, forKey: PreferenceKeys.leftTabs.rawValue)
        }
        if let rightTabData = state.rightTabManager.encodedTabs() {
            ud.set(rightTabData, forKey: PreferenceKeys.rightTabs.rawValue)
        }
        ud.set(state.leftTabManager.activeTabIDString, forKey: PreferenceKeys.leftActiveTabID.rawValue)
        ud.set(state.rightTabManager.activeTabIDString, forKey: PreferenceKeys.rightActiveTabID.rawValue)
        
        // Save sorting state
        ud.set(state.sortKey.rawValue, forKey: PreferenceKeys.sortKey.rawValue)
        ud.set(state.bSortAscending, forKey: PreferenceKeys.sortAscending.rawValue)
        
        log.info("[StatePersistence] state saved (incl. tabs L=\(state.leftTabManager.tabs.count) R=\(state.rightTabManager.tabs.count), sort=\(state.sortKey.rawValue) asc=\(state.bSortAscending))")
    }
    
    // MARK: - Load Initial Paths
    
    /// Get initial paths for panels (from UserDefaults or defaults).
    /// Validates that saved paths still exist and are accessible directories;
    /// falls back to sensible defaults otherwise.
    static func loadInitialPaths() -> (left: String, right: String) {
        let fm = FileManager.default
        let ud = UserDefaults.standard

        let defaultLeft = fm.urls(for: .downloadsDirectory, in: .userDomainMask).first?.path ?? NSHomeDirectory()
        let defaultRight = fm.urls(for: .documentDirectory, in: .userDomainMask).first?.path ?? "/Users"

        let savedLeft = ud.string(forKey: PreferenceKeys.leftPath.rawValue)
        let savedRight = ud.string(forKey: PreferenceKeys.rightPath.rawValue)

        let leftPath = validDirectoryPath(savedLeft, fallback: defaultLeft)
        let rightPath = validDirectoryPath(savedRight, fallback: defaultRight)

        log.debug("[StatePersistence] loaded paths L=\(leftPath) R=\(rightPath)")
        return (leftPath, rightPath)
    }

    /// Returns `path` if it points to an existing, accessible directory; otherwise `fallback`.
    /// Container-symlinks like ~/Library/Containers/…/Data/Downloads are resolved to real paths.
    private static func validDirectoryPath(_ path: String?, fallback: String) -> String {
        guard let path, !path.isEmpty else { return fallback }
        // Resolve container symlinks to their real paths so sandbox doesn't produce
        // '/Library/Containers/.../Data/Downloads' paths that fail on next launch.
        let resolved: String
        if let real = URL(fileURLWithPath: path).resolvingSymlinksInPath().path as String?,
           real != path {
            log.debug("[StatePersistence] container symlink resolved: \(path) → \(real)")
            resolved = real
        } else {
            resolved = path
        }
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: resolved, isDirectory: &isDir), isDir.boolValue else {
            log.warning("[StatePersistence] saved path missing/not dir: \(resolved) → fallback \(fallback)")
            return fallback
        }
        // Extra safety: skip DerivedData temp paths that may vanish between launches
        if resolved.contains("/DerivedData/") || resolved.contains(".xcarchive") {
            log.warning("[StatePersistence] saved path is ephemeral: \(resolved) → fallback \(fallback)")
            return fallback
        }
        return resolved
    }
    
    /// Get initial focused panel
    static func loadInitialFocus() -> PanelSide {
        let ud = UserDefaults.standard
        if let raw = ud.string(forKey: PreferenceKeys.lastFocusedPanel.rawValue), raw == "right" {
            return .right
        }
        return .left
    }
    
    // MARK: - Restore Tabs
    
    /// Restore saved tabs into TabManagers
    static func restoreTabs(into state: AppState) {
        let ud = UserDefaults.standard
        
        // Restore left panel tabs
        if let leftData = ud.data(forKey: PreferenceKeys.leftTabs.rawValue) {
            state.leftTabManager.restoreTabs(from: leftData)
            if let activeID = ud.string(forKey: PreferenceKeys.leftActiveTabID.rawValue) {
                state.leftTabManager.restoreActiveTabID(from: activeID)
            }
            log.debug("[StatePersistence] restored left tabs: \(state.leftTabManager.tabs.count)")
        }
        
        // Restore right panel tabs
        if let rightData = ud.data(forKey: PreferenceKeys.rightTabs.rawValue) {
            state.rightTabManager.restoreTabs(from: rightData)
            if let activeID = ud.string(forKey: PreferenceKeys.rightActiveTabID.rawValue) {
                state.rightTabManager.restoreActiveTabID(from: activeID)
            }
            log.debug("[StatePersistence] restored right tabs: \(state.rightTabManager.tabs.count)")
        }
        
        log.info("[StatePersistence] tabs restored L=\(state.leftTabManager.tabs.count) R=\(state.rightTabManager.tabs.count)")
    }
    
    // MARK: - Restore Sorting
    
    /// Restore saved sorting state
    static func restoreSorting(into state: AppState) {
        let ud = UserDefaults.standard
        
        if let sortKeyRaw = ud.string(forKey: PreferenceKeys.sortKey.rawValue),
           let sortKey = SortKeysEnum(rawValue: sortKeyRaw) {
            state.sortKey = sortKey
        }
        
        // bSortAscending defaults to true if not set
        if ud.object(forKey: PreferenceKeys.sortAscending.rawValue) != nil {
            state.bSortAscending = ud.bool(forKey: PreferenceKeys.sortAscending.rawValue)
        }
        
        log.debug("[StatePersistence] sorting restored: key=\(state.sortKey.rawValue) asc=\(state.bSortAscending)")
    }
}
