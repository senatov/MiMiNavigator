// ArchiveErrors.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 12.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Archive error types used across the Archive layer

import Foundation

// MARK: - Archive Manager Error
enum ArchiveManagerError: LocalizedError, Sendable {
    case unsupportedFormat(String)
    case extractionFailed(String)
    case repackFailed(String)
    case toolNotFound(String)
    case passwordRequired
    case wrongPassword
    case invalidArchive(String)
    case operationCancelled
    case operationTimedOut(String)

    var isPasswordRelated: Bool {
        switch self {
        case .passwordRequired, .wrongPassword:
            return true
        default:
            return false
        }
    }

    var isCancellation: Bool {
        switch self {
        case .operationCancelled:
            return true
        default:
            return false
        }
    }

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let ext):
            return "Unsupported archive format: .\(ext)"
        case .extractionFailed(let message):
            return "Extraction failed: \(message)"
        case .repackFailed(let message):
            return "Repacking failed: \(message)"
        case .toolNotFound(let message):
            return message
        case .passwordRequired:
            return "This archive requires a password."
        case .wrongPassword:
            return "The archive password is incorrect."
        case .invalidArchive(let message):
            return "Invalid archive: \(message)"
        case .operationCancelled:
            return "The archive operation was cancelled."
        case .operationTimedOut(let message):
            return "The archive operation timed out: \(message)"
        }
    }
}
