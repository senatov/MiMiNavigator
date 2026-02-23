// ActiveDialog.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 22.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Dialog types for context menu coordinator

import Foundation

// MARK: - Active Dialog Type
/// Represents different dialog types that can be shown by the coordinator
enum ActiveDialog: Identifiable {
    case deleteConfirmation(files: [CustomFile])
    case rename(file: CustomFile)
    case pack(files: [CustomFile], destination: URL)
    case createLink(file: CustomFile, destination: URL)
    case fileConflict(conflict: FileConflictInfo, continuation: CheckedContinuation<ConflictResolution, Never>)
    case error(title: String, message: String)
    case success(title: String, message: String)
    
    // Batch operation dialogs
    case batchCopyConfirmation(files: [CustomFile], destination: URL, sourcePanel: PanelSide)
    case batchMoveConfirmation(files: [CustomFile], destination: URL, sourcePanel: PanelSide)
    case batchDeleteConfirmation(files: [CustomFile], sourcePanel: PanelSide)
    case batchPackConfirmation(files: [CustomFile], destination: URL, sourcePanel: PanelSide)
    case batchProgress(state: BatchOperationState)
    
    var id: String {
        switch self {
        case .deleteConfirmation: return "delete"
        case .rename: return "rename"
        case .pack: return "pack"
        case .createLink: return "createLink"
        case .fileConflict: return "conflict"
        case .error: return "error"
        case .success: return "success"
        case .batchCopyConfirmation: return "batchCopy"
        case .batchMoveConfirmation: return "batchMove"
        case .batchDeleteConfirmation: return "batchDelete"
        case .batchPackConfirmation: return "batchPack"
        case .batchProgress: return "batchProgress"
        }
    }
}
