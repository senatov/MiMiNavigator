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

        // MARK: - Public Methods

        /// Select file on specified panel, keep opposite panel selection (shown as gray).
        /// The ".." parent directory entry is navigation-only but CAN be selected/highlighted
        /// so keyboard navigation and UI highlighting behave consistently.
        func select(_ file: CustomFile, on panelSide: PanelSide) {
            guard let state = appState else {
                log.error("[SelectionManager] appState is nil")
                return
            }
            log.debug(#function)
            // Parent entry is navigational but can still be highlighted/selected
            if ParentDirectoryEntry.isParentEntry(file) {
                log.debug("[SelectionManager] selecting parent dir entry (..)")

                var panel = state.panel(panelSide)
                panel.selectedFile = file
                state[panel: panelSide] = panel

                // Parent row is always the first visible entry
                lastKnownIndex[panelSide] = 0
                log.debug("[SelectionManager] parent entry index forced to 0")

                state.focusedPanel = panelSide
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
            let items = state.displayedFiles(for: state.focusedPanel)
            guard !items.isEmpty else {
                log.debug("[SelectionManager] moveSelection: empty list")
                return
            }
            let panelSide = state.focusedPanel
            let current = state.panel(panelSide).selectedFile
            let currentIdx: Int

            if let cached = lastKnownIndex[panelSide],
                cached >= 0,
                cached < items.count,
                current?.urlValue.standardizedFileURL == items[cached].urlValue.standardizedFileURL
            {
                // Fast path: cached index still valid
                currentIdx = cached
            } else if let cur = current {
                // Fallback: locate current file
                let curURL = cur.urlValue.standardizedFileURL
                currentIdx =
                    items.firstIndex(where: {
                        $0.urlValue.standardizedFileURL == curURL
                    }) ?? 0
                lastKnownIndex[panelSide] = currentIdx
            } else {
                currentIdx = step >= 0 ? 0 : items.count - 1
                lastKnownIndex[panelSide] = currentIdx
            }

            let nextIdx = max(0, min(items.count - 1, currentIdx + step))
            let next = items[nextIdx]

            // Record index for keyboard navigation (including parent entry)
            lastKnownIndex[panelSide] = nextIdx

            if current?.urlValue.standardizedFileURL == next.urlValue.standardizedFileURL {
                return
            }
            var panel = state.panel(state.focusedPanel)
            panel.selectedFile = next
            state[panel: state.focusedPanel] = panel
            log.debug("[SelectionManager] selection idx=\(nextIdx) file=\(next.nameStr)")
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

            if let idx = items.firstIndex(where: { $0.urlValue.standardizedFileURL == target.urlValue.standardizedFileURL }) {
                lastKnownIndex[state.focusedPanel] = idx
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
