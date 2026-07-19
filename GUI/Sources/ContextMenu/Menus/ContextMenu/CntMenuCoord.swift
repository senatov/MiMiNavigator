// CntMenuCoord.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 22.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Main coordinator for context menu actions - core state and dependencies
//
// Architecture:
//   - ActiveDialog.swift                         → Dialog enum types
//   - CntMenuCoord+FileActions.swift            → FileAction dispatching
//   - CntMenuCoord+DirectoryActions.swift       → DirectoryAction dispatching
//   - CntMenuCoord+BackgroundActions.swift      → PanelBackgroundAction dispatching
//   - CntMenuCoord+MultiSelectionActions.swift  → MultiSelectionAction dispatching
//   - CntMenuCoord+CreationOps.swift            → Create/move/copy/link operations

import AppKit
import FileModelKit
import SwiftUI

// MARK: - CntMenuCoord
/// Coordinates context menu actions with dialogs and file operations
@MainActor
@Observable
final class CntMenuCoord {

    static let shared = CntMenuCoord()

    // MARK: - State
    var activeDialog: ActiveDialog?
    var isProcessing = false

    // MARK: - Dependencies (internal for extensions)
    let fileOps = FileOpsService.shared
    let clipboard = ClipboardManager.shared
    let archiveService = ArchiveService.shared

    private init() {
        log.debug("\(#function) CntMenuCoord initialized")
        // wire conflict handler to both FileOpsService and FileOpsEngine
        let handler: (FileConflictInfo, Int) async -> BatchConflictDecision = { [weak self] conflict, remaining in
            guard let self else {
                return BatchConflictDecision(resolution: .keepBoth, applyToAll: false)
            }
            return await self.showConflictDialog(conflict: conflict, remainingCount: remaining)
        }
        fileOps.conflictHandler = handler
        FileOpsEngine.shared.conflictHandler = handler
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

    /// Show file conflict resolution dialog — returns BatchConflictDecision with applyToAll flag
    func showConflictDialog(conflict: FileConflictInfo, remainingCount: Int = 1) async -> BatchConflictDecision {
        log.debug("\(#function) source='\(conflict.sourceName)' target='\(conflict.targetName)' remaining=\(remainingCount)")
        let contentsMatch = await compareConflictContents(conflict)
        let inspectedConflict = FileConflictInfo(
            source: conflict.sourceURL,
            target: conflict.targetURL,
            contentsMatch: contentsMatch
        )
        return await FileConflictPanelCoordinator.shared.present(conflict: inspectedConflict, remainingCount: remainingCount)
    }

    // MARK: - Compare Conflict Contents

    private func compareConflictContents(_ conflict: FileConflictInfo) async -> Bool? {
        guard conflict.sourceSize == conflict.targetSize else { return false }
        let source = conflict.sourceURL
        let target = conflict.targetURL
        return await FileContentHashCache.shared.contentsEqual(source, target)
    }

    /// Resolve conflict from UI callback
    func resolveConflict(_ decision: BatchConflictDecision) {
        log.debug("\(#function) resolution=\(decision.resolution) applyToAll=\(decision.applyToAll)")
        if case .fileConflict(_, _, let continuation) = activeDialog {
            activeDialog = nil
            continuation.resume(returning: decision)
        }
    }

    // MARK: - Dialog Management

    /// Dismiss active dialog
    func dismissDialog() {
        log.debug("\(#function)")
        if case .fileConflict(_, _, let continuation) = activeDialog {
            activeDialog = nil
            continuation.resume(returning: BatchConflictDecision(resolution: .stop, applyToAll: false))
            return
        }
        activeDialog = nil
    }

}
