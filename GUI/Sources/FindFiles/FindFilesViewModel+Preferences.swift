// FindFilesViewModel+Preferences.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Persistent Find Files criteria stored in MiMiDefaults.

import Foundation

// MARK: - Find Files Preferences
extension FindFilesViewModel {
    private static var preferencesKey: String { "findFiles.preferences.v2" }

    func savePreferences() {
        let preferences = FindFilesPreferences(
            fileNamePattern: fileNamePattern,
            invertFileNamePattern: invertFileNamePattern,
            searchText: searchText,
            searchDirectory: searchDirectory,
            caseSensitive: caseSensitive,
            useRegex: useRegex,
            searchInSubdirectories: searchInSubdirectories,
            searchInArchives: searchInArchives,
            itemTypeFilter: itemTypeFilter,
            excludeSystemLocations: excludeSystemLocations,
            deletableOnly: deletableOnly,
            emptyFoldersOnly: emptyFoldersOnly,
            useSizeFilter: useSizeFilter,
            fileSizeMin: fileSizeMin,
            fileSizeMax: fileSizeMax,
            fileSizeUnit: fileSizeUnit,
            useDateFilter: useDateFilter,
            dateFrom: dateFrom,
            dateTo: dateTo,
            useStaleItemFilter: useStaleItemFilter,
            staleCriterionMode: staleCriterionMode,
            staleTimestampFilter: staleTimestampFilter,
            staleAgeAmount: staleAgeAmount,
            staleAgeUnit: staleAgeUnit,
            staleSinceDate: staleSinceDate
        )
        guard let data = try? JSONEncoder().encode(preferences) else { return }
        MiMiDefaults.shared.set(data, forKey: Self.preferencesKey)
    }

    func loadPreferences() {
        guard let data = MiMiDefaults.shared.data(forKey: Self.preferencesKey),
              let value = try? JSONDecoder().decode(FindFilesPreferences.self, from: data)
        else { return }
        fileNamePattern = value.fileNamePattern
        invertFileNamePattern = value.invertFileNamePattern
        searchText = value.searchText
        searchDirectory = value.searchDirectory
        caseSensitive = value.caseSensitive
        useRegex = value.useRegex
        searchInSubdirectories = value.searchInSubdirectories
        searchInArchives = value.searchInArchives
        itemTypeFilter = value.itemTypeFilter
        excludeSystemLocations = value.excludeSystemLocations
        deletableOnly = value.deletableOnly
        emptyFoldersOnly = value.emptyFoldersOnly
        useSizeFilter = value.useSizeFilter
        fileSizeMin = value.fileSizeMin
        fileSizeMax = value.fileSizeMax
        fileSizeUnit = value.fileSizeUnit
        useDateFilter = value.useDateFilter
        dateFrom = value.dateFrom
        dateTo = value.dateTo
        useStaleItemFilter = value.useStaleItemFilter
        staleCriterionMode = value.staleCriterionMode
        staleTimestampFilter = value.staleTimestampFilter
        staleAgeAmount = value.staleAgeAmount
        staleAgeUnit = value.staleAgeUnit
        staleSinceDate = value.staleSinceDate
    }
}

// MARK: - Stored Preferences
private struct FindFilesPreferences: Codable {
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
}
