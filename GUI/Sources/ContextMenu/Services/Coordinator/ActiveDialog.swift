// ActiveDialog.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 22.01.2026.
// Refactored: 04.02.2026
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
    case properties(file: CustomFile)
    case fileConflict(conflict: FileConflictInfo, continuation: CheckedContinuation<ConflictResolution, Never>)
    case error(title: String, message: String)
    case success(title: String, message: String)
    
    var id: String {
        switch self {
        case .deleteConfirmation: return "delete"
        case .rename: return "rename"
        case .pack: return "pack"
        case .createLink: return "createLink"
        case .properties: return "properties"
        case .fileConflict: return "conflict"
        case .error: return "error"
        case .success: return "success"
        }
    }
}
