// FindFilesViewModel+Summary.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Human-readable active criteria summary and preset matching.

import Foundation

// MARK: - Active Criteria Summary
extension FindFilesViewModel {
    var activeCriteriaSummary: [String] {
        var values: [String] = []
        let pattern = fileNamePattern.isEmpty ? "*" : fileNamePattern
        values.append(invertFileNamePattern ? "Name ≠ \(pattern)" : "Name: \(pattern)")
        if !searchText.isEmpty { values.append("Text: \(searchText)") }
        if !searchDirectory.isEmpty {
            values.append("In: \(URL(fileURLWithPath: searchDirectory).lastPathComponent.isEmpty ? searchDirectory : URL(fileURLWithPath: searchDirectory).lastPathComponent)")
        }
        values.append(itemTypeFilter.label)
        if searchInSubdirectories { values.append("Subfolders") }
        if searchInArchives { values.append("Archives") }
        if caseSensitive { values.append("Case-sensitive") }
        if useRegex { values.append("Regex") }
        if excludeSystemLocations { values.append("System locations excluded") }
        if deletableOnly { values.append("Deletable only") }
        if emptyFoldersOnly { values.append("Empty folders") }
        if useSizeFilter { values.append(sizeSummary) }
        if useDateFilter { values.append("Modified: \(Self.shortDate(dateFrom))–\(Self.shortDate(dateTo))") }
        if useStaleItemFilter { values.append(staleSummary) }
        return values
    }

    func isPresetActive(_ preset: FindFilesPreset) -> Bool {
        switch preset {
        case .largeStaleFiles:
            return itemTypeFilter == .filesOnly
                && excludeSystemLocations && deletableOnly && useSizeFilter
                && fileSizeMin == "100" && fileSizeUnit == .megabytes
                && useStaleItemFilter && staleCriterionMode == .age
                && staleTimestampFilter == .both && staleAgeAmount == "12"
                && staleAgeUnit == .months
        case .applicationLeftovers:
            return searchDirectory.hasSuffix("/Library")
                && itemTypeFilter == .filesAndFolders && deletableOnly
                && useStaleItemFilter && staleTimestampFilter == .modified
                && staleAgeAmount == "24" && staleAgeUnit == .months
        case .emptyStaleFolders:
            return itemTypeFilter == .foldersOnly
                && excludeSystemLocations && deletableOnly && emptyFoldersOnly
                && useStaleItemFilter && staleTimestampFilter == .modified
                && staleAgeAmount == "12" && staleAgeUnit == .months
        }
    }

    private var sizeSummary: String {
        let minimum = fileSizeMin.isEmpty ? "0" : fileSizeMin
        let maximum = fileSizeMax.isEmpty ? "∞" : fileSizeMax
        return "Size: \(minimum)–\(maximum) \(fileSizeUnit.label)"
    }

    private var staleSummary: String {
        let target = staleTimestampFilter.label
        switch staleCriterionMode {
        case .date:
            return "\(target) before \(Self.shortDate(staleSinceDate))"
        case .age:
            let amount = staleAgeAmount.isEmpty ? "?" : staleAgeAmount
            return "\(target) older than \(amount) \(staleAgeUnit.label.lowercased())"
        }
    }

    private static func shortDate(_ date: Date) -> String {
        date.formatted(date: .numeric, time: .omitted)
    }
}
