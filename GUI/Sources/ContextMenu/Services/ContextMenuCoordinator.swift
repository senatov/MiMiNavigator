// ContextMenuCoordinator.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 22.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Main coordinator for context menu actions - core state and dependencies
//
// Architecture:
//   - ActiveDialog.swift              → Dialog enum types
//   - FileActionsHandler.swift        → FileAction dispatching
//   - DirectoryActionsHandler.swift   → DirectoryAction dispatching
//   - PanelBackgroundActionsHandler.swift → PanelBackgroundAction dispatching
//   - FileOperationExecutors.swift    → Async file operations

import AppKit
import FileModelKit
import SwiftUI

// MARK: - Context Menu Coordinator
/// Coordinates context menu actions with dialogs and file operations
@MainActor
@Observable
final class ContextMenuCoordinator {
    
    static let shared = ContextMenuCoordinator()
    
    // MARK: - State
    var activeDialog: ActiveDialog?
    var isProcessing = false
    
    // MARK: - Dependencies (internal for extensions)
    let fileOps = FileOpsService.shared
    let clipboard = ClipboardManager.shared
    let archiveService = ArchiveService.shared
    
    private init() {
        log.debug("\(#function) ContextMenuCoordinator initialized")
    }
    
    // MARK: - Path Helpers
    
    /// Get destination path for panel
    func getDestinationPath(for panel: FavPanelSide, appState: AppState) -> URL {
        appState.url(for: panel)
    }
    
    /// Get opposite panel destination path
    func getOppositeDestinationPath(for panel: FavPanelSide, appState: AppState) -> URL {
        appState.url(for: panel == .left ? .right : .left)
    }
    
    // MARK: - Panel Refresh
    
    /// Refresh both panels after file operations
    /// Adds small delay for FSEvents to catch up, then forces full refresh
    func refreshPanels(appState: AppState) {
        log.debug("\(#function) scheduling panel refresh")
        Task { @MainActor in
            // Small delay to allow FSEvents to process filesystem changes
            try? await Task.sleep(for: .milliseconds(100))
            appState.forceRefreshBothPanels()
            log.debug("\(#function) refresh completed")
        }
    }
    
    // MARK: - Unique Name Generator
    
    /// Generate unique name for file/folder in directory
    func generateUniqueName(baseName: String, in directory: URL, isDirectory: Bool) -> URL {
        var candidateURL = directory.appendingPathComponent(baseName)
        var counter = 2
        
        let nameWithoutExt = (baseName as NSString).deletingPathExtension
        let ext = (baseName as NSString).pathExtension
        
        while FileManager.default.fileExists(atPath: candidateURL.path) {
            let newName: String
            if ext.isEmpty {
                newName = "\(nameWithoutExt) \(counter)"
            } else {
                newName = "\(nameWithoutExt) \(counter).\(ext)"
            }
            candidateURL = directory.appendingPathComponent(newName)
            counter += 1
        }
        
        log.debug("\(#function) baseName='\(baseName)' → '\(candidateURL.lastPathComponent)'")
        return candidateURL
    }
    
    // MARK: - Conflict Dialog
    
    /// Show file conflict resolution dialog
    func showConflictDialog(conflict: FileConflictInfo) async -> ConflictResolution {
        log.debug("\(#function) source='\(conflict.sourceName)' target='\(conflict.targetName)'")
        return await withCheckedContinuation { continuation in
            activeDialog = .fileConflict(conflict: conflict, continuation: continuation)
        }
    }
    
    /// Resolve conflict from UI callback
    func resolveConflict(_ resolution: ConflictResolution) {
        log.debug("\(#function) resolution=\(resolution)")
        if case .fileConflict(_, let continuation) = activeDialog {
            activeDialog = nil
            continuation.resume(returning: resolution)
        }
    }
    
    // MARK: - Dialog Management
    
    /// Dismiss active dialog
    func dismissDialog() {
        log.debug("\(#function)")
        activeDialog = nil
    }
}
