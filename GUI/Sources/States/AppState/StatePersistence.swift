// StatePersistence.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 27.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Save and restore app state to/from UserDefaults

import Foundation

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
        ud.set(state.leftPath, forKey: PersistenceKeys.lastLeftPath)
        ud.set(state.rightPath, forKey: PersistenceKeys.lastRightPath)
        
        // Save focus
        ud.set(state.focusedPanel == .left ? "left" : "right", forKey: PersistenceKeys.lastFocusedPanel)
        
        // Save selections
        if let left = state.selectedLeftFile?.urlValue {
            ud.set(left, forKey: PersistenceKeys.lastSelectedLeftFilePath)
        }
        if let right = state.selectedRightFile?.urlValue {
            ud.set(right, forKey: PersistenceKeys.lastSelectedRightFilePath)
        }
        
        log.info("[StatePersistence] state saved")
    }
    
    // MARK: - Load Initial Paths
    
    /// Get initial paths for panels (from UserDefaults or defaults)
    static func loadInitialPaths() -> (left: String, right: String) {
        let fm = FileManager.default
        let ud = UserDefaults.standard
        
        let defaultLeft = fm.urls(for: .downloadsDirectory, in: .userDomainMask).first?.path ?? ""
        let defaultRight = fm.urls(for: .documentDirectory, in: .userDomainMask).first?.path ?? ""
        
        let leftPath = ud.string(forKey: PersistenceKeys.lastLeftPath) ?? defaultLeft
        let rightPath = ud.string(forKey: PersistenceKeys.lastRightPath) ?? defaultRight
        
        log.debug("[StatePersistence] loaded paths L=\(leftPath) R=\(rightPath)")
        
        return (leftPath, rightPath)
    }
    
    /// Get initial focused panel
    static func loadInitialFocus() -> PanelSide {
        let ud = UserDefaults.standard
        if let raw = ud.string(forKey: PersistenceKeys.lastFocusedPanel), raw == "right" {
            return .right
        }
        return .left
    }
}
