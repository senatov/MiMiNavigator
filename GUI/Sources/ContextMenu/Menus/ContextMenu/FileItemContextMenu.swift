// FileItemContextMenu.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Shared context-menu routing for a file-panel item.

import AppKit
import FileModelKit
import SwiftUI

// MARK: - File Item Context Menu
@MainActor
struct FileItemContextMenu: View {
    @Environment(AppState.self) private var appState
    let file: CustomFile
    let panelSide: FavPanelSide

    // MARK: - Body
    @ViewBuilder
    var body: some View {
        let optionHeld = NSEvent.modifierFlags.contains(.option)
        if shouldUseMultiSelectionMenu {
            MultiSelectionContextMenu(
                markedCount: appState.markedCount(for: panelSide),
                panelSide: panelSide,
                isOptionHeld: optionHeld
            ) { action in
                log.debug("[ContextMenu] multi action=\(action.rawValue) panel=\(panelSide)")
                CntMenuCoord.shared.handleMultiSelectionAction(action, panel: panelSide, appState: appState)
            }
        } else if isDirectory {
            DirectoryContextMenu(file: file, panelSide: panelSide, isOptionHeld: optionHeld) { action in
                log.debug("[ContextMenu] directory action=\(action.rawValue) file='\(file.nameStr)' panel=\(panelSide)")
                CntMenuCoord.shared.handleDirectoryAction(action, for: file, panel: panelSide, appState: appState)
            }
        } else {
            FileContextMenu(file: file, panelSide: panelSide, isOptionHeld: optionHeld) { action in
                log.debug("[ContextMenu] file action=\(action.rawValue) file='\(file.nameStr)' panel=\(panelSide)")
                CntMenuCoord.shared.handleFileAction(action, for: file, panel: panelSide, appState: appState)
            }
        }
    }

    // MARK: - Selection Routing
    private var shouldUseMultiSelectionMenu: Bool {
        appState.markedCount(for: panelSide) > 1 && appState.isMarked(file, on: panelSide)
    }

    // MARK: - Directory Detection
    private var isDirectory: Bool {
        if file.isDirectory || file.isSymbolicDirectory { return true }
        var directoryFlag = ObjCBool(false)
        return FileManager.default.fileExists(atPath: file.urlValue.path, isDirectory: &directoryFlag)
            && directoryFlag.boolValue
    }
}
