// AppState+Selection.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 11.03.2026.
// Copyright © 2025-2026 Senatov. All rights reserved.
// Description: Core selection operations — uses PanelState via panel subscript.

import FileModelKit
import Foundation

// MARK: - Selection Operations
extension AppState {

    func select(_ file: CustomFile, on panel: PanelSide) {
        log.debug(#function)
        selectionManager?.select(file, on: panel)
    }

    func selectFileByName(_ name: String, on panel: PanelSide) {
        let files = displayedFiles(for: panel)
        if let match = files.first(where: { $0.nameStr == name }) {
            log.info("[Selection] selectFileByName found '\(name)' on \(panel)")
            setSelectedFile(match, for: panel)
        } else {
            log.warning("[Selection] selectFileByName FAILED: '\(name)' not found on \(panel)")
        }
    }

    func refreshAndSelect(name: String, on panel: PanelSide) async {
        log.info("[Selection] refreshAndSelect: name='\(name)' panel=\(panel)")
        await scanner.clearCooldown(for: panel)
        await refreshFiles(for: panel)
        selectFileByName(name, on: panel)
    }

    func refreshAndSelectAfterRemoval(removedFiles: [CustomFile], on panel: PanelSide) async {
        let oldFiles = displayedFiles(for: panel)
        let removedNames = Set(removedFiles.map { $0.nameStr })
        var lastRemovedIndex = 0
        for (index, file) in oldFiles.enumerated() where removedNames.contains(file.nameStr) {
            lastRemovedIndex = index
        }
        await refreshFiles(for: panel)
        let newFiles = displayedFiles(for: panel)
        guard !newFiles.isEmpty else { return }
        var targetIndex = min(lastRemovedIndex, newFiles.count - 1)
        if newFiles[targetIndex].isParentEntry && targetIndex + 1 < newFiles.count { targetIndex += 1 }
        setSelectedFile(newFiles[targetIndex], for: panel)
    }

    func clearSelection(on panel: PanelSide) { selectionManager?.clearSelection(on: panel) }

    func clearFileSelection() {
        setSelectedFile(nil, for: focusedPanel)
    }

    func toggleFocus() {
        focusedPanel = focusedPanel == .left ? .right : .left
        ensureSelectionOnFocusedPanel()
    }

    func ensureSelectionOnFocusedPanel() {
        let panel = focusedPanel
        guard self[panel: panel].selectedFile == nil else { return }
        let files = panel == .left ? displayedLeftFiles : displayedRightFiles
        if let first = files.first(where: { !$0.isParentEntry }) {
            setSelectedFile(first, for: panel)
        }
    }

    func selectionMove(by step: Int) { selectionManager?.moveSelection(by: step) }
    func selectionMoveToEdge(top: Bool) { selectionManager?.moveToEdge(top: top) }
}
