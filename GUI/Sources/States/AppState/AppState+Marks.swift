// AppState+Marks.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 11.03.2026.
// Copyright © 2025-2026 Senatov. All rights reserved.
// Description: File marking (Total Commander style) and multi-selection

import Foundation
import FileModelKit

// MARK: - Multi-Selection Operations (Total Commander + Finder style)
extension AppState {

    /// Handle click with modifier keys (Cmd, Shift, or plain) — Finder-style multi-selection
    func handleClickWithModifiers(on file: CustomFile, modifiers: ClickModifiers) {
        multiSelectionManager?.handleClick(on: file, modifiers: modifiers)
    }

    /// Toggle mark on current file and move to next (Insert key)
    func toggleMarkAndMoveNext() {
        multiSelectionManager?.toggleMarkAndMoveNext()
    }

    /// Mark files by pattern (Num+)
    func markByPattern() {
        multiSelectionManager?.markByPattern(shouldMark: true)
    }

    /// Unmark files by pattern (Num-)
    func unmarkByPattern() {
        multiSelectionManager?.markByPattern(shouldMark: false)
    }

    /// Mark all files (Ctrl+A)
    func markAll() {
        multiSelectionManager?.markAll()
    }

    /// Unmark all files
    func unmarkAll() {
        multiSelectionManager?.unmarkAll()
    }

    /// Invert marks (Num*)
    func invertMarks() {
        multiSelectionManager?.invertMarks()
    }

    /// Mark files with same extension as current
    func markSameExtension() {
        multiSelectionManager?.markSameExtension()
    }

    /// Clear marks after successful operation
    func clearMarksAfterOperation(on panel: FavPanelSide) {
        multiSelectionManager?.clearMarksAfterOperation(on: panel)
    }

    /// Clear marks on specific panel
    func unmarkAll(on panel: FavPanelSide) {
        setMarkedFiles([], for: panel)
        log.debug("[AppState] cleared all marks on \(panel)")
    }
}
