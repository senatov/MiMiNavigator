// FindFilesViewModel+Summary.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Human-readable criteria summaries for independent search modules.

import Foundation

// MARK: - Active Criteria Summary
extension FindFilesViewModel {
    var activeCriteriaSummary: [String] {
        activeModule == .general ? searchCriteriaSummary : advancedCriteriaSummary
    }

    func isPresetActive(_ preset: FindFilesPreset) -> Bool {
        advancedSettings.activePreset == preset
    }

    var activeAdvancedFilterChips: [String] {
        guard activeModule == .advanced else { return [] }
        let settings = advancedSettings
        var values: [String] = []
        if settings.itemTypeFilter != .filesAndFolders { values.append(settings.itemTypeFilter.label) }
        if settings.caseSensitive { values.append("Case-sensitive") }
        if settings.useRegex { values.append("Regex") }
        if settings.excludeSystemLocations { values.append("System locations excluded") }
        if settings.deletableOnly { values.append("Deletable only") }
        if settings.emptyFoldersOnly { values.append("Empty folders") }
        if settings.useSizeFilter { values.append(sizeSummary(settings)) }
        if settings.useDateFilter { values.append("Modified: \(Self.shortDate(settings.dateFrom))–\(Self.shortDate(settings.dateTo))") }
        if settings.useStaleItemFilter { values.append(staleSummary(settings)) }
        return values
    }

    var advancedCriteriaWarning: String? {
        let settings = advancedSettings
        let hasText = !settings.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if hasText && settings.itemTypeFilter == .foldersOnly { return "Text search requires files." }
        if settings.emptyFoldersOnly && settings.itemTypeFilter != .foldersOnly { return "Empty-folder filtering requires Folders only." }
        if settings.useSizeFilter && settings.itemTypeFilter == .foldersOnly { return "File-size filtering does not apply to folders." }
        return nil
    }

    func resetAdvancedFilters() {
        advancedSettings.itemTypeFilter = .filesAndFolders
        advancedSettings.excludeSystemLocations = false
        advancedSettings.deletableOnly = false
        advancedSettings.emptyFoldersOnly = false
        advancedSettings.useSizeFilter = false
        advancedSettings.useDateFilter = false
        advancedSettings.useStaleItemFilter = false
        advancedSettings.activePreset = nil
        log.info("[FindFiles] Advanced filters reset")
    }

    func markAdvancedCriteriaEdited() {
        guard advancedSettings.activePreset != nil else { return }
        advancedSettings.activePreset = nil
        log.debug("[FindFiles] Preset deactivated after manual criteria edit")
    }

    private var searchCriteriaSummary: [String] {
        var values = baseSummary(
            pattern: fileNamePattern,
            inverted: invertFileNamePattern,
            text: searchText,
            directory: searchDirectory,
            subdirectories: searchInSubdirectories,
            archives: searchInArchives
        )
        if caseSensitive { values.append("Case-sensitive") }
        if useRegex { values.append("Regex") }
        return values
    }

    private var advancedCriteriaSummary: [String] {
        let settings = advancedSettings
        var values = baseSummary(
            pattern: settings.fileNamePattern,
            inverted: settings.invertFileNamePattern,
            text: settings.searchText,
            directory: settings.searchDirectory,
            subdirectories: settings.searchInSubdirectories,
            archives: settings.searchInArchives
        )
        values.append(settings.itemTypeFilter.label)
        if settings.caseSensitive { values.append("Case-sensitive") }
        if settings.useRegex { values.append("Regex") }
        if settings.excludeSystemLocations { values.append("System locations excluded") }
        if settings.deletableOnly { values.append("Deletable only") }
        if settings.emptyFoldersOnly { values.append("Empty folders") }
        if settings.useSizeFilter { values.append(sizeSummary(settings)) }
        if settings.useDateFilter {
            values.append("Modified: \(Self.shortDate(settings.dateFrom))–\(Self.shortDate(settings.dateTo))")
        }
        if settings.useStaleItemFilter { values.append(staleSummary(settings)) }
        return values
    }

    private func baseSummary(
        pattern: String,
        inverted: Bool,
        text: String,
        directory: String,
        subdirectories: Bool,
        archives: Bool
    ) -> [String] {
        let effectivePattern = pattern.isEmpty ? "*" : pattern
        var values = [inverted ? "Name ≠ \(effectivePattern)" : "Name: \(effectivePattern)"]
        if !text.isEmpty { values.append("Text: \(text)") }
        if !directory.isEmpty {
            let name = URL(fileURLWithPath: directory).lastPathComponent
            values.append("In: \(name.isEmpty ? directory : name)")
        }
        if subdirectories { values.append("Subfolders") }
        if archives { values.append("Archives") }
        return values
    }

    private func sizeSummary(_ settings: FindFilesSearchSettings) -> String {
        let minimum = settings.fileSizeMin.isEmpty ? "0" : settings.fileSizeMin
        let maximum = settings.fileSizeMax.isEmpty ? "∞" : settings.fileSizeMax
        return "Size: \(minimum)–\(maximum) \(settings.fileSizeUnit.label)"
    }

    private func staleSummary(_ settings: FindFilesSearchSettings) -> String {
        let target = settings.staleTimestampFilter.label
        switch settings.staleCriterionMode {
        case .date:
            return "\(target) before \(Self.shortDate(settings.staleSinceDate))"
        case .age:
            let amount = settings.staleAgeAmount.isEmpty ? "?" : settings.staleAgeAmount
            return "\(target) older than \(amount) \(settings.staleAgeUnit.label.lowercased())"
        }
    }

    private static func shortDate(_ date: Date) -> String {
        date.formatted(date: .numeric, time: .omitted)
    }
}
