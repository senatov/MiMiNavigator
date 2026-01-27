// FileOperationError.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 27.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Error types for file operations

import Foundation

// MARK: - File Operation Errors
/// Errors that can occur during file operations
enum FileOperationError: LocalizedError {
    case fileNotFound(String)
    case fileAlreadyExists(String)
    case permissionDenied(String)
    case operationFailed(String)
    case invalidDestination(String)
    case conflict(source: URL, target: URL)
    case operationCancelled
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound(let name):
            return "File not found: \(name)"
        case .fileAlreadyExists(let name):
            return "File already exists: \(name)"
        case .permissionDenied(let path):
            return "Permission denied: \(path)"
        case .operationFailed(let reason):
            return "Operation failed: \(reason)"
        case .invalidDestination(let path):
            return "Invalid destination: \(path)"
        case .conflict(_, let target):
            return "File conflict: \(target.lastPathComponent)"
        case .operationCancelled:
            return "Operation cancelled"
        }
    }
}
