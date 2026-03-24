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

    // MARK: - Public Methods

    /// Select file on specified panel, keep opposite panel selection (shown as gray).
    /// The ".." parent directory entry is navigation-only but CAN be selected/highlighted
    /// so keyboard navigation and UI highlighting behave consistently.
    func select(_ file: CustomFile, on panelSide: PanelSide) {
        guard let state = appState else {
            log.error("[SelectionManager] appState is nil")
            return
        }
        log.debug("[SelectionManager] select file=\(file.nameStr) on=\(panelSide)")
        updatePanel(panelSide) { panel in
            panel.selectedFile = file
        }
        // Resolve index safely (no magic 0)
        let items = state.displayedFiles(for: panelSide)
        if let idx = items.firstIndex(where: { $0.urlValue.standardizedFileURL == file.urlValue.standardizedFileURL }) {
            lastKnownIndex[panelSide] = idx
        }
        state.focusedPanel = panelSide
    }

    /// Clear selection on specified panel
    func clearSelection(on panelSide: PanelSide) {
        log.debug("[SelectionManager] clearSelection on=\(panelSide)")
        updatePanel(panelSide) { panel in
            panel.selectedFile = nil
        }
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
        guard let state = appState else { return }
        let panelSide = state.focusedPanel
        let items = state.displayedFiles(for: panelSide)
        guard !items.isEmpty else {
            log.debug("[SelectionManager] moveSelection: empty list")
            return
        }
        let current = state.panel(panelSide).selectedFile
        let currentIdx = current.flatMap { currentFile in
            items.firstIndex {
                $0.urlValue.standardizedFileURL == currentFile.urlValue.standardizedFileURL
            }
        } ?? 0
        let nextIdx = max(0, min(items.count - 1, currentIdx + step))
        let next = items[nextIdx]
        updatePanel(panelSide) { panel in
            panel.selectedFile = next
        }
        lastKnownIndex[panelSide] = nextIdx
        log.debug("[SelectionManager] selection idx=\(nextIdx) file=\(next.nameStr)")
    }

    /// Move to first or last item in list
    func moveToEdge(top: Bool) {
        guard let state = appState else { return }
        let panelSide = state.focusedPanel
        let items = state.displayedFiles(for: panelSide)
        guard let target = top ? items.first : items.last else {
            log.debug("[SelectionManager] moveToEdge: empty list")
            return
        }
        updatePanel(panelSide) { panel in
            panel.selectedFile = target
        }
        if let idx = items.firstIndex(where: { $0.urlValue.standardizedFileURL == target.urlValue.standardizedFileURL }) {
            lastKnownIndex[panelSide] = idx
        }
        log.debug("[SelectionManager] moveToEdge top=\(top) file=\(target.nameStr)")
    }

    /// Toggle focus between panels
    func toggleFocus() {
        guard let state = appState else { return }
        let oldFocus = state.focusedPanel
        state.focusedPanel = oldFocus == .left ? .right : .left
        log.debug("[SelectionManager] focus toggled \(oldFocus) → \(state.focusedPanel)")
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
        restoreSelection(for: .left, key: .lastSelectedLeftFilePath)
        restoreSelection(for: .right, key: .lastSelectedRightFilePath)
    }
}