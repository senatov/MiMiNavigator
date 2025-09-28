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
        log.info(#function)
        appState.toggleFocus()
        appState.forceFocusSelection()
        if shift {
            log.info("Shift+Tab pressed → toggle focused panel (reverse)")
        } else {
            log.info("Tab pressed → toggle focused panel")
        }
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
               let idx = files.firstIndex(where: { $0.nameStr == cur.nameStr }) {
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
}
