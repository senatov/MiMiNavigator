// AppState+Selection.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 11.03.2026.
// Copyright © 2025-2026 Senatov. All rights reserved.
// Description: Core selection operations — select, clear, toggle focus

import FileModelKit
import Foundation

// MARK: - Selection Operations
extension AppState {

    func select(_ file: CustomFile, on panelSide: PanelSide) {
        log.debug(#function)
        selectionManager?.select(file, on: panelSide)
    }

    func selectFileByName(_ name: String, on panel: PanelSide) {
        let files = displayedFiles(for: panel)
        if let match = files.first(where: { $0.nameStr == name }) {
            log.info("[Selection] selectFileByName found '\(name)' on \(panel)")
            switch panel {
                case .left: selectedLeftFile = match
                case .right: selectedRightFile = match
            }
        } else {
            log.warning("[Selection] selectFileByName FAILED: '\(name)' not found on \(panel)")
        }
    }

    func refreshAndSelect(name: String, on panel: PanelSide) async {
        log.info("[Selection] refreshAndSelect: name='\(name)' panel=\(panel)")
        await scanner.clearCooldown(for: panel)
        if panel == .left { await refreshLeftFiles() } else { await refreshRightFiles() }
        selectFileByName(name, on: panel)
    }

    func refreshAndSelectAfterRemoval(removedFiles: [CustomFile], on panel: PanelSide) async {
        let oldFiles = displayedFiles(for: panel)
        let removedNames = Set(removedFiles.map { $0.nameStr })
        var lastRemovedIndex = 0
        for (index, file) in oldFiles.enumerated() where removedNames.contains(file.nameStr) {
            lastRemovedIndex = index
        }
        if panel == .left { await refreshLeftFiles() } else { await refreshRightFiles() }
        let newFiles = displayedFiles(for: panel)
        guard !newFiles.isEmpty else { return }
        var targetIndex = min(lastRemovedIndex, newFiles.count - 1)
        if newFiles[targetIndex].isParentEntry && targetIndex + 1 < newFiles.count { targetIndex += 1 }
        let targetFile = newFiles[targetIndex]
        switch panel {
            case .left: selectedLeftFile = targetFile
            case .right: selectedRightFile = targetFile
        }
    }

    func clearSelection(on panelSide: PanelSide) { selectionManager?.clearSelection(on: panelSide) }

    func clearFileSelection() {
        switch focusedPanel {
            case .left: selectedLeftFile = nil
            case .right: selectedRightFile = nil
        }
    }

    func toggleFocus() {
        focusedPanel = focusedPanel == .left ? .right : .left
        ensureSelectionOnFocusedPanel()
    }

    func ensureSelectionOnFocusedPanel() {
        switch focusedPanel {
            case .left:
                guard selectedLeftFile == nil else { return }
                if let first = displayedLeftFiles.first(where: { !$0.isParentEntry }) { selectedLeftFile = first }
            case .right:
                guard selectedRightFile == nil else { return }
                if let first = displayedRightFiles.first(where: { !$0.isParentEntry }) { selectedRightFile = first }
        }
    }

    func selectionMove(by step: Int) { selectionManager?.moveSelection(by: step) }
    func selectionMoveToEdge(top: Bool) { selectionManager?.moveToEdge(top: top) }
}
