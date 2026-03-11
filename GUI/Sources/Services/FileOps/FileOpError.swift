// FileOpError.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 11.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Unified error types for all file operations

import Foundation

// MARK: - File Operation Errors
/// Single error enum for copy, move, delete, rename, symlink
enum FileOpError: LocalizedError {
    case fileNotFound(String)
    case alreadyExists(String)
    case permissionDenied(String)
    case failed(String)
    case invalidDest(String)
    case conflict(source: URL, target: URL)
    case cancelled
    case readFailed(String)
    case writeFailed(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let p): return "File not found: \(p)"
        case .alreadyExists(let p): return "Already exists: \(p)"
        case .permissionDenied(let p): return "Permission denied: \(p)"
        case .failed(let r): return "Operation failed: \(r)"
        case .invalidDest(let p): return "Invalid destination: \(p)"
        case .conflict(_, let t): return "Conflict: \(t.lastPathComponent)"
        case .cancelled: return "Operation cancelled"
        case .readFailed(let p): return "Read failed: \(p)"
        case .writeFailed(let p): return "Write failed: \(p)"
        }
    }
}
