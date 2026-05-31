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
        return showAppKitConflictDialog(conflict: conflict, remainingCount: remainingCount)
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

    private func showAppKitConflictDialog(conflict: FileConflictInfo, remainingCount: Int) -> BatchConflictDecision {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "File already exists"
        alert.informativeText = conflictMessage(conflict)
        alert.addButton(withTitle: "Replace Existing")
        alert.addButton(withTitle: "Save as Copy")
        alert.addButton(withTitle: "Skip Incoming")
        alert.addButton(withTitle: "Cancel")
        if remainingCount > 1 {
            alert.showsSuppressionButton = true
            alert.suppressionButton?.title = "Apply to remaining"
        }
        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        let applyToAll = alert.suppressionButton?.state == .on
        let resolution = conflictResolution(for: response)
        log.debug("[Conflict] resolved via NSAlert resolution=\(resolution) applyToAll=\(applyToAll)")
        return BatchConflictDecision(resolution: resolution, applyToAll: resolution == .stop ? false : applyToAll)
    }

    private func conflictMessage(_ conflict: FileConflictInfo) -> String {
        let sourceSize = ByteCountFormatter.string(fromByteCount: conflict.sourceSize, countStyle: .file)
        let targetSize = ByteCountFormatter.string(fromByteCount: conflict.targetSize, countStyle: .file)
        return "A file named \"\(conflict.targetName)\" already exists in the destination.\n\nExisting: \(conflict.targetURL.path)\nSize: \(targetSize)\n\nIncoming: \(conflict.sourceURL.path)\nSize: \(sourceSize)"
    }

    private func conflictResolution(for response: NSApplication.ModalResponse) -> ConflictResolution {
        switch response {
        case .alertFirstButtonReturn:
            return .replace
        case .alertSecondButtonReturn:
            return .keepBoth
        case .alertThirdButtonReturn:
            return .skip
        default:
            return .stop
        }
    }
}
