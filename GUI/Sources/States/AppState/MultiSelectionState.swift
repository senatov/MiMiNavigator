// MultiSelectionState.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 05.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Multi-selection state — accesses PanelState.markedFiles directly.

import FileModelKit
import Foundation

// MARK: - Multi-Selection State
extension AppState {

    /// Get marked files for panel
    func markedFiles(for panel: PanelSide) -> Set<String> {
        self[panel: panel].markedFiles
    }

    /// Set marked files for panel.
    /// Marking is exclusive — marks on the opposite panel are cleared automatically.
    func setMarkedFiles(_ files: Set<String>, for panel: PanelSide) {
        let opposite: PanelSide = panel == .left ? .right : .left
        self[panel: panel].markedFiles = files
        if !files.isEmpty && !self[panel: opposite].markedFiles.isEmpty {
            log.debug("[MultiSelection] clearing \(opposite) marks (marking started on \(panel))")
            self[panel: opposite].markedFiles = []
        }
    }

    /// Check if file is marked
    func isMarked(_ file: CustomFile, on panel: PanelSide) -> Bool {
        self[panel: panel].markedFiles.contains(file.id)
    }

    /// Get marked CustomFile objects for panel
    func markedCustomFiles(for panel: PanelSide) -> [CustomFile] {
        let marked = markedFiles(for: panel)
        return displayedFiles(for: panel).filter { marked.contains($0.id) }
    }

    /// Get files for operation: marked files if any, otherwise selected file.
    func filesForOperation(on panel: PanelSide) -> [CustomFile] {
        let marked = markedCustomFiles(for: panel)
        if !marked.isEmpty { return marked }
        let selected = self[panel: panel].selectedFile
        if let file = selected, !file.isParentEntry { return [file] }
        return []
    }

    /// Count of marked files
    func markedCount(for panel: PanelSide) -> Int {
        self[panel: panel].markedFiles.count
    }

    /// Total size of marked files
    func markedTotalSize(for panel: PanelSide) -> Int64 {
        markedCustomFiles(for: panel).reduce(0) { $0 + $1.sizeInBytes }
    }
}
