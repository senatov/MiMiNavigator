// DuoFilePanelActions.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 27.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: File operation actions for the dual-panel view

import AppKit
import Foundation

/// File operation actions performed from DuoFilePanelView
/// Extracted to separate concerns from the main view
@MainActor
struct DuoFilePanelActions {
    let appState: AppState
    let refreshBothPanels: () async -> Void
    
    // MARK: - F3 View
    func performView() {
        log.debug("performView - View button pressed")
        
        guard FileActions.isVSCodeInstalled() else {
            FileActions.promptVSCodeInstall { }
            return
        }
        
        guard let file = currentSelectedFile else {
            log.debug("No file selected for View")
            return
        }
        
        guard !file.isDirectory else {
            log.debug("Cannot view directory")
            return
        }
        
        FileActions.view(file)
    }

    // MARK: - F4 Edit
    func performEdit() {
        log.debug("performEdit - Edit button pressed")
        
        guard FileActions.isVSCodeInstalled() else {
            FileActions.promptVSCodeInstall { }
            return
        }
        
        guard let file = currentSelectedFile else {
            log.debug("No file selected for Edit")
            return
        }
        
        guard !file.isDirectory else {
            log.debug("Cannot edit directory")
            return
        }
        
        FileActions.edit(file)
    }

    // MARK: - F5 Copy
    func performCopy() {
        log.debug("performCopy - Copy button pressed")
        
        guard let source = currentSelectedFile else {
            log.debug("No file selected for Copy")
            return
        }
        
        guard let destination = targetPanelURL else {
            log.debug("No destination panel available")
            return
        }
        
        FileActions.copyWithConfirmation(source, to: destination) {
            Task {
                await refreshBothPanels()
            }
        }
    }

    // MARK: - F6 Move
    func performMove() {
        log.debug("performMove - Move button pressed")
        
        guard let source = currentSelectedFile else {
            log.debug("No file selected for Move")
            return
        }
        
        guard let destination = targetPanelURL else {
            log.debug("No destination panel available")
            return
        }
        
        FileActions.moveWithConfirmation(source, to: destination) {
            Task {
                await refreshBothPanels()
            }
        }
    }

    // MARK: - F7 New Folder
    func performNewFolder() {
        log.debug("performNewFolder - New Folder button pressed")
        
        guard let currentURL = appState.pathURL(for: appState.focusedPanel) else {
            log.debug("No current directory for New Folder")
            return
        }
        
        FileActions.createFolderWithDialog(at: currentURL) {
            Task {
                await refreshBothPanels()
            }
        }
    }

    // MARK: - F8 Delete
    func performDelete() {
        log.debug("performDelete - Delete button pressed")
        
        guard let file = currentSelectedFile else {
            log.debug("No file selected for Delete")
            return
        }
        
        FileActions.deleteWithConfirmation(file) {
            Task {
                await refreshBothPanels()
            }
        }
    }

    // MARK: - Settings
    func performSettings() {
        log.debug("performSettings - Settings button pressed")
        // TODO: Implement settings panel
    }

    // MARK: - Console
    func performConsole() {
        log.debug("performConsole - Console button pressed")
        let path = appState.pathURL(for: appState.focusedPanel)?.path ?? "/"
        _ = ConsoleCurrPath.open(in: path)
    }

    // MARK: - Exit
    func performExit() {
        log.debug("performExit - Exit button pressed")
        appState.saveBeforeExit()
        NSApplication.shared.terminate(nil)
    }
    
    // MARK: - Computed Properties
    
    private var currentSelectedFile: CustomFile? {
        appState.focusedPanel == .left ? appState.selectedLeftFile : appState.selectedRightFile
    }
    
    private var targetPanelURL: URL? {
        let targetSide: PanelSide = appState.focusedPanel == .left ? .right : .left
        return appState.pathURL(for: targetSide)
    }
}
