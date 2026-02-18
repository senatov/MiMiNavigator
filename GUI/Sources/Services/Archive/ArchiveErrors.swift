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

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let ext): return "Unsupported archive format: .\(ext)"
        case .extractionFailed(let msg):  return "Extraction failed: \(msg)"
        case .repackFailed(let msg):      return "Repacking failed: \(msg)"
        case .toolNotFound(let msg):      return msg
        }
    }
}
