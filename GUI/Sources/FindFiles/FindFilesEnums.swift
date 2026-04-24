// FindFilesEnums.swift
// MiMiNavigator
//
// Extracted from FindFilesViewModel.swift
// Copyright © 2026 Senatov. All rights reserved.
// Description: Enums for Find Files UI state and filter options

import Foundation

// MARK: - Search State
enum FindFilesState: Equatable {
    case idle
    case searching
    case paused
    case completed
    case cancelled
}

// MARK: - Age Unit
enum FindFilesAgeUnit: String, CaseIterable, Identifiable {
    case days = "days"
    case months = "months"
    case years = "years"

    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}
// MARK: - Stale Criterion Mode
enum FindFilesStaleCriterionMode: String, CaseIterable, Identifiable {
    case date
    case age

    var id: String { rawValue }

    var label: String {
        switch self {
        case .date: return "Date"
        case .age: return "Age"
        }
    }
}

// MARK: - Timestamp Filter
enum FindFilesTimestampFilter: String, CaseIterable, Identifiable {
    case modified
    case accessed
    case both

    var id: String { rawValue }

    var label: String {
        switch self {
        case .modified: return "Modified"
        case .accessed: return "Accessed"
        case .both: return "Both"
        }
    }
}
// MARK: - Item Type Filter
enum FindFilesItemTypeFilter: String, CaseIterable, Identifiable {
    case filesAndFolders
    case filesOnly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .filesAndFolders: return "Files and folders"
        case .filesOnly: return "Files only"
        }
    }
}

// MARK: - Size Unit
enum FindFilesSizeUnit: String, CaseIterable, Identifiable {
    case bytes = "B"
    case kilobytes = "KB"
    case megabytes = "MB"
    case gigabytes = "GB"

    var id: String { rawValue }
    var label: String { rawValue }

    var multiplier: Int64 {
        switch self {
        case .bytes: return 1
        case .kilobytes: return 1024
        case .megabytes: return 1024 * 1024
        case .gigabytes: return 1024 * 1024 * 1024
        }
    }
}