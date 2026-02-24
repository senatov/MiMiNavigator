// SelectionManager.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 27.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Manages file selection state and history for both panels

import Foundation
import FileModelKit

// MARK: - Selection Manager
/// Handles all selection-related operations for dual-panel file manager
@MainActor
final class SelectionManager {
    
    // MARK: - Dependencies
    private weak var appState: AppState?
    private let selectionsHistory: SelectionsHistory
    
    // MARK: - State
    private var isRestoringSelections = false
    private var lastRecordedPathLeft: String?
    private var lastRecordedPathRight: String?
    
    // MARK: - Initialization
    init(appState: AppState, history: SelectionsHistory) {
        self.appState = appState
        self.selectionsHistory = history
        log.debug("[SelectionManager] initialized")
    }
    
    // MARK: - Public Methods
    
    /// Select file on specified panel, keep opposite panel selection (shown as gray)
    func select(_ file: CustomFile, on panelSide: PanelSide) {
        guard let state = appState else {
            log.error("[SelectionManager] appState is nil")
            return
        }
        
        log.debug("[SelectionManager] select file=\(file.nameStr) on=\(panelSide)")
        
        switch panelSide {
        case .left:
            state.selectedLeftFile = file
        case .right:
            state.selectedRightFile = file
        }
        
        state.focusedPanel = panelSide
        log.debug("[SelectionManager] focus changed to \(panelSide)")
    }
    
    /// Clear selection on specified panel
    func clearSelection(on panelSide: PanelSide) {
        guard let state = appState else { return }
        
        log.debug("[SelectionManager] clearSelection on=\(panelSide)")
        
        switch panelSide {
        case .left:
            state.selectedLeftFile = nil
        case .right:
            state.selectedRightFile = nil
        }
    }

    /// Record selection to history (called from didSet)
    func recordSelection(_ panelSide: PanelSide, file: CustomFile?) {
        guard let f = file else { return }
        let path = PathUtils.canonical(f.urlValue)
        
        guard !isRestoringSelections else {
            log.debug("[SelectionManager] history skip (restoring)")
            return
        }
        
        // Prevent duplicate entries
        switch panelSide {
        case .left:
            if lastRecordedPathLeft == path {
                log.debug("[SelectionManager] history skip dupe L")
                return
            }
            lastRecordedPathLeft = path
            
        case .right:
            if lastRecordedPathRight == path {
                log.debug("[SelectionManager] history skip dupe R")
                return
            }
            lastRecordedPathRight = path
        }
        
        log.debug("[SelectionManager] history add \(panelSide): \(path)")
        selectionsHistory.setCurrent(to: path)
        selectionsHistory.add(path)
    }
    
    /// Move selection up/down by step count
    func moveSelection(by step: Int) {
        guard let state = appState else { return }
        
        let items = state.displayedFiles(for: state.focusedPanel)
        guard !items.isEmpty else {
            log.debug("[SelectionManager] moveSelection: empty list")
            return
        }
        
        let current = state.focusedPanel == .left ? state.selectedLeftFile : state.selectedRightFile
        let currentIdx: Int
        
        if let cur = current {
            let curPath = PathUtils.canonical(cur.urlValue)
            currentIdx = items.firstIndex { PathUtils.canonical($0.urlValue) == curPath } ?? 0
        } else {
            currentIdx = step >= 0 ? 0 : items.count - 1
        }
        
        let nextIdx = max(0, min(items.count - 1, currentIdx + step))
        let next = items[nextIdx]
        
        if state.focusedPanel == .left {
            state.selectedLeftFile = next
        } else {
            state.selectedRightFile = next
        }
        
        log.debug("[SelectionManager] moved to idx=\(nextIdx) file=\(next.nameStr)")
    }
    
    /// Toggle focus between panels
    func toggleFocus() {
        guard let state = appState else { return }
        
        let oldFocus = state.focusedPanel
        state.focusedPanel = oldFocus == .left ? .right : .left
        log.debug("[SelectionManager] focus toggled \(oldFocus) → \(state.focusedPanel)")
    }
    
    /// Restore selections and focus from UserDefaults
    func restoreSelectionsAndFocus() {
        guard let state = appState else { return }
        
        log.debug("[SelectionManager] restoreSelectionsAndFocus")
        isRestoringSelections = true
        defer { isRestoringSelections = false }
        
        let ud = UserDefaults.standard
        
        // Restore focus
        if let raw = ud.string(forKey: PreferenceKeys.lastFocusedPanel.rawValue), raw == "right" {
            state.focusedPanel = .right
        } else {
            state.focusedPanel = .left
        }
        
        // Restore left selection
        if let leftUrl = ud.url(forKey: PreferenceKeys.lastSelectedLeftFilePath.rawValue) {
            if let match = state.displayedLeftFiles.first(where: {
                PathUtils.canonical($0.urlValue) == PathUtils.canonical(leftUrl)
            }) {
                state.selectedLeftFile = match
                log.debug("[SelectionManager] restored L: \(match.nameStr)")
            }
        }
        
        // Restore right selection
        if let rightUrl = ud.url(forKey: PreferenceKeys.lastSelectedRightFilePath.rawValue) {
            if let match = state.displayedRightFiles.first(where: {
                PathUtils.canonical($0.urlValue) == PathUtils.canonical(rightUrl)
            }) {
                state.selectedRightFile = match
                log.debug("[SelectionManager] restored R: \(match.nameStr)")
            }
        }
    }
}
