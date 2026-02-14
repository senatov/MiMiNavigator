// FileTableView+Actions.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 04.02.2026.
// Copyright © 2024-2026 Senatov. All rights reserved.
// Description: Action handlers for FileTableView

import SwiftUI

// MARK: - Actions
extension FileTableView {
    
    func handleFileAction(_ action: FileAction, for file: CustomFile) {
        log.debug("\(#function) action=\(action.rawValue) file='\(file.nameStr)' panel=\(panelSide)")
        ContextMenuCoordinator.shared.handleFileAction(action, for: file, panel: panelSide, appState: appState)
    }
    
    func handleDirectoryAction(_ action: DirectoryAction, for file: CustomFile) {
        log.debug("\(#function) action=\(action.rawValue) dir='\(file.nameStr)' panel=\(panelSide)")
        ContextMenuCoordinator.shared.handleDirectoryAction(action, for: file, panel: panelSide, appState: appState)
    }
    
    func handleMultiSelectionAction(_ action: MultiSelectionAction) {
        log.debug("\(#function) action=\(action.rawValue) panel=\(panelSide) markedCount=\(appState.markedCount(for: panelSide))")
        ContextMenuCoordinator.shared.handleMultiSelectionAction(action, panel: panelSide, appState: appState)
    }

    func handlePanelBackgroundAction(_ action: PanelBackgroundAction) {
        log.debug("\(#function) action=\(action.rawValue) panel=\(panelSide)")
        ContextMenuCoordinator.shared.handlePanelBackgroundAction(action, for: panelSide, appState: appState)
    }
}
