// FileActionsHandler.swift
// MiMiNavigator
//
// Created by Claude AI on 04.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Handles FileAction dispatching from context menu

import AppKit
import Foundation

// MARK: - File Actions Handler
/// Extension handling FileAction dispatching
extension ContextMenuCoordinator {
    
    /// Handles file context menu actions
    func handleFileAction(_ action: FileAction, for file: CustomFile, panel: PanelSide, appState: AppState) {
        log.debug("\(#function) action=\(action.rawValue) file='\(file.nameStr)' panel=\(panel)")
        
        switch action {
        case .open:
            openFile(file)
            
        case .openWith:
            // Handled by OpenWithSubmenu directly
            log.debug("\(#function) openWith handled by submenu")
            
        case .viewLister:
            openQuickLook(file)
            
        case .cut:
            clipboard.cut(files: [file], from: panel)
            
        case .copy:
            clipboard.copy(files: [file], from: panel)
            
        case .paste:
            Task {
                await performPaste(to: panel, appState: appState)
            }
            
        case .duplicate:
            Task {
                await performDuplicate(file: file, appState: appState)
            }
            
        case .compress:
            Task {
                await performCompress(files: [file], appState: appState)
            }
            
        case .pack:
            let destination = getOppositeDestinationPath(for: panel, appState: appState)
            log.debug("\(#function) pack destination='\(destination.path)'")
            activeDialog = .pack(files: [file], destination: destination)
            
        case .createLink:
            let destination = getOppositeDestinationPath(for: panel, appState: appState)
            log.debug("\(#function) createLink destination='\(destination.path)'")
            activeDialog = .createLink(file: file, destination: destination)
            
        case .share:
            ShareService.shared.showSharePicker(for: [file.urlValue])
            
        case .revealInFinder:
            RevealInFinderService.shared.revealInFinder(file.urlValue)
            
        case .rename:
            activeDialog = .rename(file: file)
            
        case .delete:
            activeDialog = .deleteConfirmation(files: [file])
            
        case .getInfo:
            GetInfoService.shared.showGetInfo(for: file.urlValue)
            
        case .properties:
            activeDialog = .properties(file: file)
        }
    }
    
    // MARK: - Private File Helpers
    
    /// Opens file with default application
    func openFile(_ file: CustomFile) {
        log.debug("\(#function) file='\(file.nameStr)' path='\(file.pathStr)'")
        NSWorkspace.shared.open(file.urlValue)
    }
    
    /// Opens Quick Look preview panel
    func openQuickLook(_ file: CustomFile) {
        log.debug("\(#function) file='\(file.nameStr)'")
        QuickLookService.shared.preview(file: file.urlValue)
    }
}
