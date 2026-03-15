// AppState+KeyboardNav.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 15.03.2026.
// Copyright © 2025-2026 Senatov. All rights reserved.
// Description: Keyboard navigation — arrow keys, page up/down, home/end, mark+move

import FileModelKit
import Foundation

// MARK: - Keyboard Navigation
extension AppState {

    func navigateUp() { navigationCallbacks[focusedPanel]?.moveUp() }
    func navigateDown() { navigationCallbacks[focusedPanel]?.moveDown() }
    func navigatePageUp() { navigationCallbacks[focusedPanel]?.pageUp() }
    func navigatePageDown() { navigationCallbacks[focusedPanel]?.pageDown() }
    func navigateToFirst() { navigationCallbacks[focusedPanel]?.jumpToFirst() }
    func navigateToLast() { navigationCallbacks[focusedPanel]?.jumpToLast() }

    // MARK: - Mark current file and move (Shift+Up/Down)
    func markCurrentAndMove(direction: Int) {
        let panel = focusedPanel
        let selectedFile = self[panel: panel].selectedFile
        guard let file = selectedFile, !file.isParentEntry else {
            if direction < 0 { navigateUp() } else { navigateDown() }
            return
        }
        var marked = markedFiles(for: panel)
        if marked.contains(file.id) { marked.remove(file.id) } else { marked.insert(file.id) }
        setMarkedFiles(marked, for: panel)
        if direction < 0 { navigateUp() } else { navigateDown() }
    }
}
