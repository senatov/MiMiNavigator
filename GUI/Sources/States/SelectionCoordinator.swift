//
//  SelectionCoordinator.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 27.09.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import Foundation
import SwiftUI

// MARK: -
@MainActor
final class SelectionCoordinator {
    private let appState: AppState

    // MARK: -
    init(appState: AppState) {
        self.appState = appState
    }

    // MARK: -
    func togglePanel(shift: Bool) {
        // English-only comments:
        // Delegate to coordinator if available; otherwise perform a safe local toggle.
        log.debug("togglePanel(shift: \(shift))")
        if let coordinator = (self as AnyObject).value(forKey: "coordinator") as? SelectionCoordinator {
            coordinator.togglePanel(shift: shift)
            return
        }

        switch appState.focusedPanel {
        case .left:
            appState.focusedPanel = .right
            if appState.selectedRightFile == nil,
                let first = appState.displayedRightFiles.first
            {
                appState.selectedRightFile = first
            }
        case .right:
            appState.focusedPanel = .left
            if appState.selectedLeftFile == nil,
                let first = appState.displayedLeftFiles.first
            {
                appState.selectedLeftFile = first
            }
        }
        // Ensure selection/focus coherence
        self.syncSelectionWithFocus()
    }

    // MARK: -
    func moveSelection(step: Int) {
        log.info(#function)
        let side = appState.focusedPanel
        let files: [CustomFile]
        let current: CustomFile?
        switch side {
        case .left:
            files = appState.displayedLeftFiles
            current = appState.selectedLeftFile
        case .right:
            files = appState.displayedRightFiles
            current = appState.selectedRightFile
        }
        guard !files.isEmpty else {
            log.info("No files to move selection within")
            return
        }
        var index: Int = {
            if let cur = current,
                let idx = files.firstIndex(where: { $0.nameStr == cur.nameStr })
            {
                return idx
            }
            return step > 0 ? -1 : 0
        }()
        // Clamp index into valid bounds in case the list changed asynchronously
        index = max(-1, min(index, files.count - 1))
        let next = (index + step + files.count) % files.count
        let newSel = files[next]
        switch side {
        case .left:
            appState.selectedLeftFile = newSel
        case .right:
            appState.selectedRightFile = newSel
        }
        log.info("Selection moved to: \(newSel.nameStr) [side: \(side)]")
    }

    // MARK: -
    func copySelection() {
        log.info(#function)
        let source =
            (appState.focusedPanel == .left)
            ? appState.selectedLeftFile
            : appState.selectedRightFile
        let targetSide: PanelSide = (appState.focusedPanel == .left) ? .right : .left

        if let file = source, let targetURL = appState.pathURL(for: targetSide) {
            FActions.copy(file, to: targetURL)
            Task { @MainActor in
                await appState.refreshFiles()
            }
        } else {
            log.info("No source file selected or target URL missing for Copy")
        }
    }

    // MARK: -
    /// Keep selection consistent with the currently focused panel.
    /// If focus is on the left, clear right selection and ensure left has a selection; and vice versa.
    private func syncSelectionWithFocus() {
        log.debug("syncSelectionWithFocus: now \(appState.focusedPanel)")
        switch appState.focusedPanel {
        case .left:
            if appState.selectedRightFile != nil {
                log.debug("Clearing right selection because focus moved to left")
                appState.selectedRightFile = nil
            }
            if appState.selectedLeftFile == nil, let first = appState.displayedLeftFiles.first {
                log.debug("Auto-select first left item: \(first.nameStr)")
                appState.selectedLeftFile = first
            }
        case .right:
            if appState.selectedLeftFile != nil {
                log.debug("Clearing left selection because focus moved to right")
                appState.selectedLeftFile = nil
            }
            if appState.selectedRightFile == nil, let first = appState.displayedRightFiles.first {
                log.debug("Auto-select first right item: \(first.nameStr)")
                appState.selectedRightFile = first
            }
        }
    }
}
