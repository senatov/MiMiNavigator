// MultiSelectionManager.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 05.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Total Commander style multi-selection management

import Foundation
import AppKit

// MARK: - Multi Selection Manager
/// Handles Total Commander style file marking operations
@MainActor
final class MultiSelectionManager {
    
    // MARK: - Dependencies
    private weak var appState: AppState?
    
    // MARK: - Initialization
    init(appState: AppState) {
        self.appState = appState
        log.debug("[MultiSelectionManager] initialized")
    }
    
    // MARK: - Toggle Mark (Insert key)
    /// Toggle mark on current file and move to next (Total Commander Insert behavior)
    func toggleMarkAndMoveNext() {
        guard let state = appState else { return }
        let panel = state.focusedPanel
        
        // Get current selected file
        let selectedFile: CustomFile? = panel == .left ? state.selectedLeftFile : state.selectedRightFile
        guard let file = selectedFile else {
            log.debug("[MultiSelectionManager] no file selected for toggle")
            return
        }
        
        // Skip ".." parent directory
        guard file.nameStr != ".." else {
            log.debug("[MultiSelectionManager] skipping parent dir marker")
            state.selectionMove(by: 1)
            return
        }
        
        // Toggle mark
        var marked = state.markedFiles(for: panel)
        if marked.contains(file.id) {
            marked.remove(file.id)
            log.debug("[MultiSelectionManager] unmarked: \(file.nameStr)")
        } else {
            marked.insert(file.id)
            log.debug("[MultiSelectionManager] marked: \(file.nameStr)")
        }
        state.setMarkedFiles(marked, for: panel)
        
        // Move to next file
        state.selectionMove(by: 1)
    }
    
    // MARK: - Mark by Pattern (Num+ / Num-)
    /// Show pattern dialog and mark/unmark matching files
    func markByPattern(shouldMark: Bool) {
        guard let state = appState else { return }
        
        let alert = NSAlert()
        alert.messageText = shouldMark 
            ? L10n.Selection.markByPattern 
            : L10n.Selection.unmarkByPattern
        alert.informativeText = L10n.Selection.patternHint
        alert.alertStyle = .informational
        alert.addButton(withTitle: L10n.Button.ok)
        alert.addButton(withTitle: L10n.Button.cancel)
        
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        textField.stringValue = "*.*"
        textField.placeholderString = "*.txt, *.jpg, photo*"
        alert.accessoryView = textField
        alert.window.initialFirstResponder = textField
        
        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }
        
        let pattern = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pattern.isEmpty else { return }
        
        applyPattern(pattern, shouldMark: shouldMark, on: state.focusedPanel)
    }
    
    /// Apply pattern to mark/unmark files
    private func applyPattern(_ pattern: String, shouldMark: Bool, on panel: PanelSide) {
        guard let state = appState else { return }
        
        let files = state.displayedFiles(for: panel)
        var marked = state.markedFiles(for: panel)
        var matchCount = 0
        
        for file in files {
            // Skip parent directory
            guard file.nameStr != ".." else { continue }
            
            if matchesPattern(file.nameStr, pattern: pattern) {
                if shouldMark {
                    marked.insert(file.id)
                } else {
                    marked.remove(file.id)
                }
                matchCount += 1
            }
        }
        
        state.setMarkedFiles(marked, for: panel)
        log.info("[MultiSelectionManager] pattern '\(pattern)' \(shouldMark ? "marked" : "unmarked") \(matchCount) files")
    }
    
    /// Simple wildcard pattern matching (* and ?)
    private func matchesPattern(_ name: String, pattern: String) -> Bool {
        // Convert wildcard pattern to regex
        var regexPattern = NSRegularExpression.escapedPattern(for: pattern)
        regexPattern = regexPattern.replacingOccurrences(of: "\\*", with: ".*")
        regexPattern = regexPattern.replacingOccurrences(of: "\\?", with: ".")
        regexPattern = "^" + regexPattern + "$"
        
        do {
            let regex = try NSRegularExpression(pattern: regexPattern, options: .caseInsensitive)
            let range = NSRange(name.startIndex..., in: name)
            return regex.firstMatch(in: name, range: range) != nil
        } catch {
            log.error("[MultiSelectionManager] invalid pattern regex: \(error)")
            return false
        }
    }
    
    // MARK: - Mark All (Ctrl+A / Cmd+A)
    /// Mark all files in focused panel
    func markAll() {
        guard let state = appState else { return }
        let panel = state.focusedPanel
        
        let files = state.displayedFiles(for: panel)
        var marked = Set<String>()
        
        for file in files {
            // Skip parent directory
            guard file.nameStr != ".." else { continue }
            marked.insert(file.id)
        }
        
        state.setMarkedFiles(marked, for: panel)
        log.info("[MultiSelectionManager] marked all: \(marked.count) files on \(panel)")
    }
    
    // MARK: - Unmark All
    /// Clear all marks on focused panel
    func unmarkAll() {
        guard let state = appState else { return }
        let panel = state.focusedPanel
        
        state.setMarkedFiles([], for: panel)
        log.info("[MultiSelectionManager] cleared all marks on \(panel)")
    }
    
    // MARK: - Invert Selection (Num*)
    /// Invert all marks on focused panel
    func invertMarks() {
        guard let state = appState else { return }
        let panel = state.focusedPanel
        
        let files = state.displayedFiles(for: panel)
        var marked = state.markedFiles(for: panel)
        
        for file in files {
            // Skip parent directory
            guard file.nameStr != ".." else { continue }
            
            if marked.contains(file.id) {
                marked.remove(file.id)
            } else {
                marked.insert(file.id)
            }
        }
        
        state.setMarkedFiles(marked, for: panel)
        log.info("[MultiSelectionManager] inverted marks on \(panel): \(marked.count) now marked")
    }
    
    // MARK: - Mark Same Extension
    /// Mark all files with same extension as current
    func markSameExtension() {
        guard let state = appState else { return }
        let panel = state.focusedPanel
        
        let selectedFile: CustomFile? = panel == .left ? state.selectedLeftFile : state.selectedRightFile
        guard let file = selectedFile else { return }
        
        let ext = file.fileExtension.lowercased()
        guard !ext.isEmpty else {
            log.debug("[MultiSelectionManager] no extension to match")
            return
        }
        
        applyPattern("*.\(ext)", shouldMark: true, on: panel)
    }
    
    // MARK: - Clear Marks After Operation
    /// Clear marks on panel after successful operation
    func clearMarksAfterOperation(on panel: PanelSide) {
        guard let state = appState else { return }
        state.setMarkedFiles([], for: panel)
        log.debug("[MultiSelectionManager] cleared marks after operation on \(panel)")
    }
}
