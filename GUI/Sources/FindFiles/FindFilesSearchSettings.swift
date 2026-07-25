// FindFilesSearchSettings.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Independent persisted settings for Search and Advanced Search.

import Foundation

// MARK: - Find Files Search Settings
struct FindFilesSearchSettings: Codable {
    var fileNamePattern: String = "*.*"
    var invertFileNamePattern: Bool = false
    var searchText: String = ""
    var searchDirectory: String = ""
    var caseSensitive: Bool = false
    var useRegex: Bool = false
    var searchInSubdirectories: Bool = true
    var searchInArchives: Bool = false
    var itemTypeFilter: FindFilesItemTypeFilter = .filesAndFolders
    var excludeSystemLocations: Bool = false
    var deletableOnly: Bool = false
    var emptyFoldersOnly: Bool = false
    var activePreset: FindFilesPreset?
    var useSizeFilter: Bool = false
    var fileSizeMin: String = ""
    var fileSizeMax: String = ""
    var fileSizeUnit: FindFilesSizeUnit = .megabytes
    var useDateFilter: Bool = false
    var dateFrom: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    var dateTo: Date = Date()
    var useStaleItemFilter: Bool = false
    var staleCriterionMode: FindFilesStaleCriterionMode = .age
    var staleTimestampFilter: FindFilesTimestampFilter = .both
    var staleAgeAmount: String = ""
    var staleAgeUnit: FindFilesAgeUnit = .months
    var staleSinceDate: Date = Calendar.current.date(byAdding: .year, value: -2, to: Date()) ?? Date()
}
