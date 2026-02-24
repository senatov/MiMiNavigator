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
        
        // Save user preferences
        UserPreferences.shared.capture(from: state)
        UserPreferences.shared.save()
        
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
        
        log.info("[StatePersistence] state saved (incl. tabs L=\(state.leftTabManager.tabs.count) R=\(state.rightTabManager.tabs.count))")
    }
    
    // MARK: - Load Initial Paths
    
    /// Get initial paths for panels (from UserDefaults or defaults)
    static func loadInitialPaths() -> (left: String, right: String) {
        let fm = FileManager.default
        let ud = UserDefaults.standard
        
        let defaultLeft = fm.urls(for: .downloadsDirectory, in: .userDomainMask).first?.path ?? ""
        let defaultRight = fm.urls(for: .documentDirectory, in: .userDomainMask).first?.path ?? ""
        
        let leftPath = ud.string(forKey: PreferenceKeys.leftPath.rawValue) ?? defaultLeft
        let rightPath = ud.string(forKey: PreferenceKeys.rightPath.rawValue) ?? defaultRight
        
        log.debug("[StatePersistence] loaded paths L=\(leftPath) R=\(rightPath)")
        
        return (leftPath, rightPath)
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
}
