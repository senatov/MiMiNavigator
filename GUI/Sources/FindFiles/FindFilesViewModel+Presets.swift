// FindFilesViewModel+Presets.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Advanced Find Files presets and criteria translation.

import FindFilesKit
import Foundation

// MARK: - Advanced Presets
extension FindFilesViewModel {
    func applyPotentialBallastPreset() {
        applyLargeStaleFilesPreset()
    }

    func applyLargeStaleFilesPreset() {
        applyPresetDefaults(.largeStaleFiles)
        advancedSettings.searchDirectory = FileManager.default.homeDirectoryForCurrentUser.path
        advancedSettings.searchInSubdirectories = true
        advancedSettings.itemTypeFilter = .filesOnly
        advancedSettings.emptyFoldersOnly = false
        advancedSettings.useSizeFilter = true
        advancedSettings.fileSizeMin = "100"
        advancedSettings.fileSizeMax = ""
        advancedSettings.fileSizeUnit = .megabytes
        advancedSettings.staleTimestampFilter = .both
        advancedSettings.staleAgeAmount = "12"
        advancedSettings.staleAgeUnit = .months
    }

    func applyApplicationLeftoversPreset() {
        applyPresetDefaults(.applicationLeftovers)
        advancedSettings.searchDirectory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true).path
        advancedSettings.searchInSubdirectories = false
        advancedSettings.itemTypeFilter = .filesAndFolders
        advancedSettings.emptyFoldersOnly = false
        advancedSettings.useSizeFilter = false
        advancedSettings.staleTimestampFilter = .modified
        advancedSettings.staleAgeAmount = "24"
        advancedSettings.staleAgeUnit = .months
    }

    func applyEmptyStaleFoldersPreset() {
        applyPresetDefaults(.emptyStaleFolders)
        advancedSettings.searchDirectory = FileManager.default.homeDirectoryForCurrentUser.path
        advancedSettings.searchInSubdirectories = true
        advancedSettings.itemTypeFilter = .foldersOnly
        advancedSettings.emptyFoldersOnly = true
        advancedSettings.useSizeFilter = false
        advancedSettings.staleTimestampFilter = .modified
        advancedSettings.staleAgeAmount = "12"
        advancedSettings.staleAgeUnit = .months
    }

    private func applyPresetDefaults(_ preset: FindFilesPreset) {
        advancedSettings.activePreset = preset
        log.info("[FindFiles] Applied preset: \(preset.rawValue)")
        advancedSettings.fileNamePattern = "*"
        advancedSettings.searchText = ""
        advancedSettings.caseSensitive = false
        advancedSettings.useRegex = false
        advancedSettings.searchInArchives = false
        advancedSettings.excludeSystemLocations = true
        advancedSettings.deletableOnly = true
        advancedSettings.useDateFilter = false
        advancedSettings.useStaleItemFilter = true
        advancedSettings.staleCriterionMode = .age
    }

    var activeSearchSettings: FindFilesSearchSettings {
        if activeModule == .advanced { return advancedSettings }
        var settings = FindFilesSearchSettings()
        settings.fileNamePattern = fileNamePattern
        settings.invertFileNamePattern = invertFileNamePattern
        settings.searchText = searchText
        settings.searchDirectory = searchDirectory
        settings.caseSensitive = caseSensitive
        settings.useRegex = useRegex
        settings.searchInSubdirectories = searchInSubdirectories
        settings.searchInArchives = searchInArchives
        return settings
    }

    func staleAgeDaysIfNeeded() -> Int? {
        let settings = activeSearchSettings
        guard activeModule == .advanced, settings.useStaleItemFilter, settings.staleCriterionMode == .age else { return nil }
        guard let days = ageInDays(amount: settings.staleAgeAmount, unit: settings.staleAgeUnit) else {
            errorMessage = "Enter a positive age value."
            return nil
        }
        return days
    }

    func applyStaleCriteria(to criteria: inout FindFilesCriteria, settings: FindFilesSearchSettings, staleAgeDays: Int?) {
        guard activeModule == .advanced, settings.useStaleItemFilter else { return }
        let appliesToModified = settings.staleTimestampFilter == .modified || settings.staleTimestampFilter == .both
        let appliesToAccessed = settings.staleTimestampFilter == .accessed || settings.staleTimestampFilter == .both
        switch settings.staleCriterionMode {
            case .age:
                if appliesToModified { criteria.modificationOlderThanDays = staleAgeDays }
                if appliesToAccessed { criteria.accessOlderThanDays = staleAgeDays }
            case .date:
                if appliesToModified { criteria.modificationBeforeDate = settings.staleSinceDate }
                if appliesToAccessed { criteria.accessBeforeDate = settings.staleSinceDate }
        }
    }

    private func ageInDays(amount: String, unit: FindFilesAgeUnit) -> Int? {
        guard let value = Int(amount.trimmingCharacters(in: .whitespacesAndNewlines)), value > 0 else { return nil }
        switch unit {
            case .days: return value
            case .months: return value * 30
            case .years: return value * 365
        }
    }
}
