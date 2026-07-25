// FindFilesViewModel+Preferences.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Independent persistence for Search and Advanced Search.

import Foundation

// MARK: - Find Files Preferences
extension FindFilesViewModel {
    private static var searchPreferencesKey: String { "findFiles.search.preferences.v1" }
    private static var advancedPreferencesKey: String { "findFiles.advanced.preferences.v1" }
    private static var legacyPreferencesKey: String { "findFiles.preferences.v2" }

    func savePreferences() {
        saveSearchPreferences()
        if let data = try? JSONEncoder().encode(advancedSettings) {
            MiMiDefaults.shared.set(data, forKey: Self.advancedPreferencesKey)
        }
    }

    func loadPreferences() {
        let legacy = loadLegacyPreferences()
        if let data = MiMiDefaults.shared.data(forKey: Self.searchPreferencesKey),
           let settings = try? JSONDecoder().decode(FindFilesSearchSettings.self, from: data)
        {
            applySearchSettings(settings)
        } else if let legacy {
            applyLegacySearchSettings(legacy)
        }
        if let data = MiMiDefaults.shared.data(forKey: Self.advancedPreferencesKey),
           let settings = try? JSONDecoder().decode(FindFilesSearchSettings.self, from: data)
        {
            advancedSettings = settings
        } else if let legacy {
            advancedSettings = legacy.advancedSettings
        }
    }

    private func saveSearchPreferences() {
        var settings = FindFilesSearchSettings()
        settings.fileNamePattern = fileNamePattern
        settings.invertFileNamePattern = invertFileNamePattern
        settings.searchText = searchText
        settings.searchDirectory = searchDirectory
        settings.caseSensitive = caseSensitive
        settings.useRegex = useRegex
        settings.searchInSubdirectories = searchInSubdirectories
        settings.searchInArchives = searchInArchives
        if let data = try? JSONEncoder().encode(settings) {
            MiMiDefaults.shared.set(data, forKey: Self.searchPreferencesKey)
        }
    }

    private func applySearchSettings(_ settings: FindFilesSearchSettings) {
        fileNamePattern = settings.fileNamePattern
        invertFileNamePattern = settings.invertFileNamePattern
        searchText = settings.searchText
        searchDirectory = settings.searchDirectory
        caseSensitive = settings.caseSensitive
        useRegex = settings.useRegex
        searchInSubdirectories = settings.searchInSubdirectories
        searchInArchives = settings.searchInArchives
    }

    private func applyLegacySearchSettings(_ legacy: LegacyFindFilesPreferences) {
        fileNamePattern = legacy.fileNamePattern
        invertFileNamePattern = legacy.invertFileNamePattern
        searchText = legacy.searchText
        searchDirectory = legacy.searchDirectory
        caseSensitive = legacy.caseSensitive
        useRegex = legacy.useRegex
        searchInSubdirectories = legacy.searchInSubdirectories
        searchInArchives = legacy.searchInArchives
    }

    private func loadLegacyPreferences() -> LegacyFindFilesPreferences? {
        guard let data = MiMiDefaults.shared.data(forKey: Self.legacyPreferencesKey) else { return nil }
        return try? JSONDecoder().decode(LegacyFindFilesPreferences.self, from: data)
    }
}

// MARK: - Legacy Find Files Preferences
private struct LegacyFindFilesPreferences: Codable {
    let fileNamePattern: String
    let invertFileNamePattern: Bool
    let searchText: String
    let searchDirectory: String
    let caseSensitive: Bool
    let useRegex: Bool
    let searchInSubdirectories: Bool
    let searchInArchives: Bool
    let itemTypeFilter: FindFilesItemTypeFilter
    let excludeSystemLocations: Bool
    let deletableOnly: Bool
    let emptyFoldersOnly: Bool
    let useSizeFilter: Bool
    let fileSizeMin: String
    let fileSizeMax: String
    let fileSizeUnit: FindFilesSizeUnit
    let useDateFilter: Bool
    let dateFrom: Date
    let dateTo: Date
    let useStaleItemFilter: Bool
    let staleCriterionMode: FindFilesStaleCriterionMode
    let staleTimestampFilter: FindFilesTimestampFilter
    let staleAgeAmount: String
    let staleAgeUnit: FindFilesAgeUnit
    let staleSinceDate: Date

    var advancedSettings: FindFilesSearchSettings {
        var settings = FindFilesSearchSettings()
        settings.fileNamePattern = fileNamePattern
        settings.invertFileNamePattern = invertFileNamePattern
        settings.searchText = searchText
        settings.searchDirectory = searchDirectory
        settings.caseSensitive = caseSensitive
        settings.useRegex = useRegex
        settings.searchInSubdirectories = searchInSubdirectories
        settings.searchInArchives = searchInArchives
        settings.itemTypeFilter = itemTypeFilter
        settings.excludeSystemLocations = excludeSystemLocations
        settings.deletableOnly = deletableOnly
        settings.emptyFoldersOnly = emptyFoldersOnly
        settings.useSizeFilter = useSizeFilter
        settings.fileSizeMin = fileSizeMin
        settings.fileSizeMax = fileSizeMax
        settings.fileSizeUnit = fileSizeUnit
        settings.useDateFilter = useDateFilter
        settings.dateFrom = dateFrom
        settings.dateTo = dateTo
        settings.useStaleItemFilter = useStaleItemFilter
        settings.staleCriterionMode = staleCriterionMode
        settings.staleTimestampFilter = staleTimestampFilter
        settings.staleAgeAmount = staleAgeAmount
        settings.staleAgeUnit = staleAgeUnit
        settings.staleSinceDate = staleSinceDate
        return settings
    }
}
