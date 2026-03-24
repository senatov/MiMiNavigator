// SelectionManager.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 27.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Manages file selection state and selection restoration for both panels

import FileModelKit
import Foundation

// MARK: - Selection Manager
/// Handles all selection-related operations for dual-panel file manager
@MainActor
final class SelectionManager {
    // MARK: - Dependencies
    private weak var appState: AppState?
    private let selectionsHistory: SelectionsHistory
    // MARK: - State
    private var isRestoringSelections = false
    private var lastRecordedURL: [PanelSide: URL] = [:]
    private var lastKnownIndex: [PanelSide: Int] = [:]
    private var lastKnownID: [PanelSide: CustomFile.ID] = [:]
    private var isUserNavigationInProgress: Bool = false

    private func beginUserNavigation(_ reason: String) {
        log.debug("[SelectionManager] beginUserNavigation: \(reason)")
        isUserNavigationInProgress = true
    }

    private func endUserNavigation(_ reason: String) {
        log.debug("[SelectionManager] endUserNavigation: \(reason)")
        isUserNavigationInProgress = false
    }



    // MARK: - Initialization
    init(appState: AppState, history: SelectionsHistory) {
        self.appState = appState
        self.selectionsHistory = history
        log.debug("[SelectionManager] initialized")
    }

    // MARK: - Panel Update Helper (avoids copy-mutate bugs)
    private func updatePanel(_ side: PanelSide, mutate: (inout PanelState) -> Void) {
        guard let state = appState else { return }
        var panel = state.panel(side)
        mutate(&panel)
        state[panel: side] = panel
    }

    // MARK: - Selection Safety

    /// Ensures a valid selection exists (fixes cases when selection becomes nil)
    func ensureSelectionExists(on panelSide: PanelSide) {
        guard !isRestoringSelections else { return }
        guard let state = appState else { return }

        log.debug("[SelectionManager] ensureSelectionExists start panel=\(panelSide)")

        // Do not interfere during explicit user navigation (keyboard/mouse)
        if isUserNavigationInProgress {
            log.debug("[SelectionManager] ensureSelectionExists skipped (user navigation)")
            return
        }

        let items = state.displayedFiles(for: panelSide)
        guard !items.isEmpty else {
            log.debug("[SelectionManager] ensureSelectionExists skipped (empty items)")
            return
        }

        let current = state.panel(panelSide).selectedFile

        // If parent entry is selected — do NOT override it
        if let current, current.isParentEntry {
            log.debug("[SelectionManager] skip ensureSelection (parent entry)")
            return
        }

        // If selection exists and is still valid → do nothing.
        if let current,
           items.contains(where: { $0.id == current.id }) {
            log.debug("[SelectionManager] ensureSelectionExists keep current selection")
            return
        }

        // Restore by last known stable ID first.
        if let lastID = lastKnownID[panelSide],
           let match = items.first(where: { $0.id == lastID }) {
            updatePanel(panelSide) { panel in
                panel.selectedFile = match
            }
            if let idx = items.firstIndex(where: { $0.id == match.id }) {
                lastKnownIndex[panelSide] = idx
            }
            log.debug("[SelectionManager] restore(id)=\(lastID)")
            return
        }

        // Then try restore from last known index.
        if let idx = lastKnownIndex[panelSide],
           items.indices.contains(idx) {
            let restored = items[idx]
            updatePanel(panelSide) { panel in
                panel.selectedFile = restored
            }
            lastKnownID[panelSide] = restored.id
            log.debug("[SelectionManager] restore(index) idx=\(idx)")
            return
        }

        // Prefer parent entry as fallback, otherwise first item.
        let fallback = items.first(where: { $0.isParentEntry }) ?? items[0]

        // Avoid redundant mutation if already equal somehow.
        if current?.id == fallback.id {
            log.debug("[SelectionManager] ensureSelectionExists skip (already fallback)")
            return
        }

        updatePanel(panelSide) { panel in
            panel.selectedFile = fallback
        }
        if let idx = items.firstIndex(where: { $0.id == fallback.id }) {
            lastKnownIndex[panelSide] = idx
        }
        lastKnownID[panelSide] = fallback.id
        log.debug("[SelectionManager] fallback selection file=\(fallback.nameStr)")
    }

    // MARK: - Public Methods

    /// Select file on specified panel, keep opposite panel selection (shown as gray).
    /// The ".." parent directory entry is navigation-only but CAN be selected/highlighted
    /// so keyboard navigation and UI highlighting behave consistently.
    func select(_ file: CustomFile, on panelSide: PanelSide) {
        beginUserNavigation("select")
        guard let state = appState else {
            log.error("[SelectionManager] appState is nil")
            endUserNavigation("select")
            return
        }
        log.debug("[SelectionManager] select file=\(file.nameStr) on=\(panelSide)")
        updatePanel(panelSide) { panel in
            panel.selectedFile = file
        }
        // Resolve index safely (no magic 0)
        let items = state.displayedFiles(for: panelSide)
        if let idx = items.firstIndex(where: { $0.id == file.id }) {
            lastKnownIndex[panelSide] = idx
        }
        lastKnownID[panelSide] = file.id
        state.focusedPanel = panelSide
        endUserNavigation("select")
    }

    /// Clear selection on specified panel
    func clearSelection(on panelSide: PanelSide) {
        log.debug("[SelectionManager] clearSelection on=\(panelSide)")
        updatePanel(panelSide) { panel in
            panel.selectedFile = nil
        }
        lastKnownID[panelSide] = nil
        lastKnownIndex[panelSide] = nil
        log.debug("[SelectionManager] cleared cached selection state for \(panelSide)")
    }

    /// Record selection to history (called from didSet)
    func recordSelection(_ panelSide: PanelSide, file: CustomFile?) {
        guard !isRestoringSelections else {
            log.debug("[SelectionManager] history skip (restoring)")
            return
        }
        guard let file else {
            log.debug("[SelectionManager] history skip (nil file)")
            return
        }
        let url = file.urlValue.standardizedFileURL

        if lastRecordedURL[panelSide]?.standardizedFileURL == url {
            log.debug("[SelectionManager] history skip dupe panel=\(panelSide)")
            return
        }
        lastRecordedURL[panelSide] = url
        // Only set current item. Do not push navigation history here.
        // Real navigation history must be updated only when entering directories.
        selectionsHistory.setCurrent(to: url)
    }

    /// Move selection up/down by step count
    func moveSelection(by step: Int) {
        beginUserNavigation("moveSelection step=\(step)")
        guard let state = appState else { endUserNavigation("moveSelection"); return }
        let panelSide = state.focusedPanel
        let items = state.displayedFiles(for: panelSide)
        guard !items.isEmpty else {
            log.debug("[SelectionManager] moveSelection: empty list")
            endUserNavigation("moveSelection")
            return
        }
        let current = state.panel(panelSide).selectedFile
        let currentIdx = current.flatMap { currentFile in
            items.firstIndex { $0.id == currentFile.id }
        } ?? 0
        let nextIdx = max(0, min(items.count - 1, currentIdx + step))
        let next = items[nextIdx]
        updatePanel(panelSide) { panel in
            panel.selectedFile = next
        }
        lastKnownIndex[panelSide] = nextIdx
        lastKnownID[panelSide] = next.id
        log.debug("[SelectionManager] selection idx=\(nextIdx) file=\(next.nameStr)")
        endUserNavigation("moveSelection")
    }

    /// Move to first or last item in list
    func moveToEdge(top: Bool) {
        beginUserNavigation("moveToEdge top=\(top)")
        guard let state = appState else { endUserNavigation("moveToEdge"); return }
        let panelSide = state.focusedPanel
        let items = state.displayedFiles(for: panelSide)
        guard let target = top ? items.first : items.last else {
            log.debug("[SelectionManager] moveToEdge: empty list")
            endUserNavigation("moveToEdge")
            return
        }
        updatePanel(panelSide) { panel in
            panel.selectedFile = target
        }
        if let idx = items.firstIndex(where: { $0.id == target.id }) {
            lastKnownIndex[panelSide] = idx
        }
        lastKnownID[panelSide] = target.id
        log.debug("[SelectionManager] moveToEdge top=\(top) file=\(target.nameStr)")
        endUserNavigation("moveToEdge")
    }

    /// Toggle focus between panels
    func toggleFocus() {
        guard let state = appState else { return }
        let oldFocus = state.focusedPanel
        state.focusedPanel = oldFocus == .left ? .right : .left
        log.debug("[SelectionManager] focus toggled \(oldFocus) → \(state.focusedPanel)")
        log.debug("[SelectionManager] ensureSelectionExists after focus switch")
        ensureSelectionExists(on: state.focusedPanel)
    }

    private func restoreSelection(for side: PanelSide, key: PreferenceKeys) {
        guard let state = appState else { return }
        let ud = MiMiDefaults.shared
        guard let url = ud.url(forKey: key.rawValue)?.standardizedFileURL else { return }
        let items = state.displayedFiles(for: side)
        guard let match = items.first(where: { $0.urlValue.standardizedFileURL == url }) else { return }
        updatePanel(side) { panel in
            panel.selectedFile = match
        }
        if let idx = items.firstIndex(where: { $0.id == match.id }) {
            lastKnownIndex[side] = idx
        }
        lastKnownID[side] = match.id
        log.debug("[SelectionManager] restored \(side): \(match.nameStr)")
    }

    /// Restore selections and focus from UserDefaults
    func restoreSelectionsAndFocus() {
        guard let state = appState else { return }
        log.debug("[SelectionManager] restoreSelectionsAndFocus")
        isRestoringSelections = true
        defer { isRestoringSelections = false }
        let ud = MiMiDefaults.shared
        // Restore focus
        if let raw = ud.string(forKey: PreferenceKeys.lastFocusedPanel.rawValue), raw == "right" {
            state.focusedPanel = .right
        } else {
            state.focusedPanel = .left
        }
        log.debug("[SelectionManager] restoring selections for both panels")
        restoreSelection(for: .left, key: .lastSelectedLeftFilePath)
        restoreSelection(for: .right, key: .lastSelectedRightFilePath)
        ensureSelectionExists(on: .left)
        ensureSelectionExists(on: .right)
    }
}
