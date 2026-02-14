// MultiSelectionState.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 05.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Multi-selection state extension for AppState (Total Commander style)

import Foundation

// MARK: - Multi-Selection State Extension
extension AppState {
    
    /// Get marked files for panel (file IDs = paths)
    func markedFiles(for panelSide: PanelSide) -> Set<String> {
        switch panelSide {
        case .left: return markedLeftFiles
        case .right: return markedRightFiles
        }
    }
    
    /// Set marked files for panel.
    /// Marking is exclusive — marks on the opposite panel are cleared automatically.
    func setMarkedFiles(_ files: Set<String>, for panelSide: PanelSide) {
        switch panelSide {
        case .left:
            markedLeftFiles = files
            if !files.isEmpty && !markedRightFiles.isEmpty {
                log.debug("[MultiSelection] clearing right marks (marking started on left)")
                markedRightFiles = []
            }
        case .right:
            markedRightFiles = files
            if !files.isEmpty && !markedLeftFiles.isEmpty {
                log.debug("[MultiSelection] clearing left marks (marking started on right)")
                markedLeftFiles = []
            }
        }
    }
    
    /// Check if file is marked
    func isMarked(_ file: CustomFile, on panelSide: PanelSide) -> Bool {
        markedFiles(for: panelSide).contains(file.id)
    }
    
    /// Get marked CustomFile objects for panel
    func markedCustomFiles(for panelSide: PanelSide) -> [CustomFile] {
        let marked = markedFiles(for: panelSide)
        let files = displayedFiles(for: panelSide)
        return files.filter { marked.contains($0.id) }
    }
    
    /// Get files for operation: marked files if any, otherwise selected file
    func filesForOperation(on panelSide: PanelSide) -> [CustomFile] {
        let marked = markedCustomFiles(for: panelSide)
        if !marked.isEmpty {
            return marked
        }
        
        // Fallback to single selected file
        let selected: CustomFile? = panelSide == .left ? selectedLeftFile : selectedRightFile
        if let file = selected {
            return [file]
        }
        
        return []
    }
    
    /// Count of marked files
    func markedCount(for panelSide: PanelSide) -> Int {
        markedFiles(for: panelSide).count
    }
    
    /// Total size of marked files
    func markedTotalSize(for panelSide: PanelSide) -> Int64 {
        markedCustomFiles(for: panelSide).reduce(0) { $0 + $1.sizeInBytes }
    }
}
