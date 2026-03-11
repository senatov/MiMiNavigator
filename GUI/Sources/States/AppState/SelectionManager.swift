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
        private var lastRecordedPath: [PanelSide: String] = [:]

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
            var panel = state.panel(panelSide)
            panel.selectedFile = file
            state[panel: panelSide] = panel
            state.focusedPanel = panelSide
            log.debug("[SelectionManager] focus changed to \(panelSide)")
        }

        /// Clear selection on specified panel
        func clearSelection(on panelSide: PanelSide) {
            guard let state = appState else { return }

            log.debug("[SelectionManager] clearSelection on=\(panelSide)")

            var panel = state.panel(panelSide)
            panel.selectedFile = nil
            state[panel: panelSide] = panel
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
            let path = url.path

            if lastRecordedPath[panelSide] == path {
                log.debug("[SelectionManager] history skip dupe panel=\(panelSide)")
                return
            }
            lastRecordedPath[panelSide] = path

            // Only set current item. Do not push navigation history here.
            // Real navigation history must be updated only when entering directories.
            selectionsHistory.setCurrent(to: url)
        }

        /// Move selection up/down by step count
        func moveSelection(by step: Int) {
            guard let state = appState else { return }

            let items = state.displayedFiles(for: state.focusedPanel)
            guard !items.isEmpty else {
                log.debug("[SelectionManager] moveSelection: empty list")
                return
            }

            let current = state.panel(state.focusedPanel).selectedFile
            let currentIdx: Int

            if let cur = current {
                let curPath = cur.urlValue.standardizedFileURL.path

                currentIdx = items.firstIndex {
                    $0.urlValue.standardizedFileURL.path == curPath
                } ?? 0
            } else {
                currentIdx = step >= 0 ? 0 : items.count - 1
            }

            let nextIdx = max(0, min(items.count - 1, currentIdx + step))
            let next = items[nextIdx]

            if current?.urlValue.standardizedFileURL.path == next.urlValue.standardizedFileURL.path {
                return
            }

            var panel = state.panel(state.focusedPanel)
            panel.selectedFile = next
            state[panel: state.focusedPanel] = panel
            log.debug("[SelectionManager] moved to idx=\(nextIdx) file=\(next.nameStr)")
        }

        /// Move to first or last item in list
        func moveToEdge(top: Bool) {
            guard let state = appState else { return }
            let items = state.displayedFiles(for: state.focusedPanel)
            guard let target = top ? items.first : items.last else {
                log.debug("[SelectionManager] moveToEdge: empty list")
                return
            }

            var panel = state.panel(state.focusedPanel)
            panel.selectedFile = target
            state[panel: state.focusedPanel] = panel
            log.debug("[SelectionManager] moveToEdge top=\(top) file=\(target.nameStr)")
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
            if let leftURL = ud.url(forKey: PreferenceKeys.lastSelectedLeftFilePath.rawValue)?.standardizedFileURL {
                let leftItems = state.displayedFiles(for: .left)
                if let match = leftItems.first(where: { $0.urlValue.standardizedFileURL == leftURL }) {
                    var leftPanel = state.panel(.left)
                    leftPanel.selectedFile = match
                    state[panel: .left] = leftPanel
                    log.debug("[SelectionManager] restored L: \(match.nameStr)")
                }
            }

            // Restore right selection
            if let rightURL = ud.url(forKey: PreferenceKeys.lastSelectedRightFilePath.rawValue)?.standardizedFileURL {
                let rightItems = state.displayedFiles(for: .right)
                if let match = rightItems.first(where: { $0.urlValue.standardizedFileURL == rightURL }) {
                    var rightPanel = state.panel(.right)
                    rightPanel.selectedFile = match
                    state[panel: .right] = rightPanel
                    log.debug("[SelectionManager] restored R: \(match.nameStr)")
                }
            }
        }
    }
