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

    func select(_ file: CustomFile, on panel: FavPanelSide) {
        log.debug(#function)
        selectionManager?.select(file, on: panel)
    }

    func selectFileByName(_ name: String, on panel: FavPanelSide) {
        let files = displayedFiles(for: panel)
        if let match = files.first(where: { $0.nameStr == name }) {
            log.info("[Selection] selectFileByName found '\(name)' on \(panel)")
            setSelectedFile(match, for: panel)
        } else {
            log.warning("[Selection] selectFileByName FAILED: '\(name)' not found on \(panel)")
        }
    }

    func refreshAndSelect(name: String, on panel: FavPanelSide) async {
        log.info("[Selection] refreshAndSelect: name='\(name)' panel=\(panel)")
        await refreshFiles(for: panel, force: true)
        selectFileByName(name, on: panel)
    }

    func refreshAndSelectAfterRemoval(removedFiles: [CustomFile], on panel: FavPanelSide) async {
        log.debug("[REFRESH] ⏱ START refreshAndSelectAfterRemoval panel=\(panel), removedFiles=\(removedFiles.map(\.nameStr))")
        
        let oldFiles = displayedFiles(for: panel)
        log.debug("[REFRESH] oldFiles.count=\(oldFiles.count)")
        
        let removedNames = Set(removedFiles.map { $0.nameStr })
        var lastRemovedIndex = 0
        for (index, file) in oldFiles.enumerated() where removedNames.contains(file.nameStr) {
            lastRemovedIndex = index
        }
        log.debug("[REFRESH] lastRemovedIndex=\(lastRemovedIndex)")
        
        // Use force=true to bypass cooldown after file operations
        log.debug("[REFRESH] ⏱ calling refreshFiles(force: true)...")
        let startRefresh = CFAbsoluteTimeGetCurrent()
        await refreshFiles(for: panel, force: true)
        let refreshElapsed = CFAbsoluteTimeGetCurrent() - startRefresh
        log.debug("[REFRESH] ⏱ refreshFiles done in \(String(format: "%.3f", refreshElapsed))s")
        
        let newFiles = displayedFiles(for: panel)
        log.debug("[REFRESH] newFiles.count=\(newFiles.count)")
        
        guard !newFiles.isEmpty else {
            log.debug("[REFRESH] newFiles is empty (dir now empty), skipping selection")
            return
        }
        var targetIndex = min(lastRemovedIndex, newFiles.count - 1)
        if newFiles[targetIndex].isParentEntry && targetIndex + 1 < newFiles.count { targetIndex += 1 }
        log.debug("[REFRESH] selecting file at index=\(targetIndex): \(newFiles[targetIndex].nameStr)")
        setSelectedFile(newFiles[targetIndex], for: panel)
        log.debug("[REFRESH] ⏱ END refreshAndSelectAfterRemoval")
    }

    func clearSelection(on panel: FavPanelSide) { selectionManager?.clearSelection(on: panel) }

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
