// ArchivePreferences.swift
// MiMiNavigator
//
// Created by Claude on 18.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Per-format archive preferences — compression level, password storage option

import Foundation

// MARK: - Compression Level

/// Compression level presets for archive formats
enum CompressionLevel: Int, Codable, CaseIterable, Identifiable, Sendable {
    case store = 0      // No compression
    case fastest = 1    // Fastest, minimal compression
    case fast = 3       // Fast
    case normal = 5     // Balanced (default)
    case good = 7       // Better compression
    case best = 9       // Maximum compression
    
    var id: Int { rawValue }
    
    var displayName: String {
        switch self {
        case .store:   return "Store (no compression)"
        case .fastest: return "Fastest"
        case .fast:    return "Fast"
        case .normal:  return "Normal"
        case .good:    return "Good"
        case .best:    return "Best (slowest)"
        }
    }
    
    var shortName: String {
        switch self {
        case .store:   return "Store"
        case .fastest: return "Fastest"
        case .fast:    return "Fast"
        case .normal:  return "Normal"
        case .good:    return "Good"
        case .best:    return "Best"
        }
    }
}

// MARK: - Format Preferences

/// Per-format archive settings
struct ArchiveFormatPrefs: Codable, Sendable {
    var compressionLevel: CompressionLevel = .normal
    var usePassword: Bool = false
    /// Password stored in Keychain, not here
}
