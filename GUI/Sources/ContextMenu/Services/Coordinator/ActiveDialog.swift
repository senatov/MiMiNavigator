// ActiveDialog.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 22.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Dialog types for context menu coordinator

import FileModelKit
import Foundation

// MARK: - Active Dialog Type
/// Represents different dialog types that can be shown by the coordinator
enum ActiveDialog: Identifiable {
    // MARK: - Single-item dialogs
    case deleteConfirmation(files: [CustomFile])
    case rename(file: CustomFile, panel: FavPanelSide)
    case pack(files: [CustomFile], destination: URL, sourcePanel: FavPanelSide)
    case compress(files: [CustomFile], destination: URL, sourcePanel: FavPanelSide)
    case createLink(file: CustomFile, destination: URL)
    case createFolder(parentURL: URL)

    // MARK: - Conflict / result dialogs
    case fileConflict(conflict: FileConflictInfo, remainingCount: Int, continuation: CheckedContinuation<BatchConflictDecision, Never>)
    case error(title: String, message: String)
    case success(title: String, message: String)

    // MARK: - Batch operation dialogs
    case batchCopyConfirmation(files: [CustomFile], destination: URL, sourcePanel: FavPanelSide)
    case batchMoveConfirmation(files: [CustomFile], destination: URL, sourcePanel: FavPanelSide)
    case batchDeleteConfirmation(files: [CustomFile], sourcePanel: FavPanelSide)
    case batchPackConfirmation(files: [CustomFile], destination: URL, sourcePanel: FavPanelSide)
    case batchProgress(state: BatchOperationState)

    var id: String {
        switch self {
            case .deleteConfirmation:
                return "delete"
            case .rename:
                return "rename"
            case .pack:
                return "pack"
            case .compress:
                return "compress"
            case .createLink:
                return "createLink"
            case .createFolder:
                return "createFolder"
            case .fileConflict:
                return "conflict"
            case .error:
                return "error"
            case .success:
                return "success"
            case .batchCopyConfirmation:
                return "batchCopy"
            case .batchMoveConfirmation:
                return "batchMove"
            case .batchDeleteConfirmation:
                return "batchDelete"
            case .batchPackConfirmation:
                return "batchPack"
            case .batchProgress:
                return "batchProgress"
        }
    }
}
