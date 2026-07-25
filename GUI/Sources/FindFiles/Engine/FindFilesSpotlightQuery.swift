// FindFilesSpotlightQuery.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Builds indexed macOS Spotlight queries for compatible file searches.

import Foundation

// MARK: - Spotlight Query
enum FindFilesSpotlightQuery {
    // MARK: - Compatibility
    static func supports(_ criteria: FindFilesCriteria) -> Bool {
        !criteria.isArchiveOnlySearch
            && !criteria.isSingleFileContentSearch
            && !criteria.isContentSearch
            && !criteria.searchInArchives
            && !criteria.useRegex
            && !criteria.invertFileNamePattern
            && !criteria.deletableOnly
            && !criteria.excludeSystemLocations
            && criteria.searchInSubdirectories
            && !criteria.emptyFoldersOnly
            && criteria.dateFrom == nil
            && criteria.dateTo == nil
            && criteria.modificationBeforeDate == nil
            && criteria.accessBeforeDate == nil
            && criteria.modificationOlderThanDays == nil
            && criteria.accessOlderThanDays == nil
    }

    // MARK: - Process
    static func makeProcess(criteria: FindFilesCriteria) -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
        process.arguments = ["-onlyin", criteria.searchDirectory.path, query(criteria: criteria)]
        return process
    }

    // MARK: - Query
    private static func query(criteria: FindFilesCriteria) -> String {
        var predicates: [String] = []
        if let namePredicate = namePredicate(criteria: criteria) {
            predicates.append(namePredicate)
        }
        switch criteria.itemType {
        case .filesAndFolders:
            break
        case .filesOnly:
            predicates.append("kMDItemContentTypeTree != 'public.folder'")
        case .foldersOnly:
            predicates.append("kMDItemContentTypeTree == 'public.folder'")
        }
        if let minimum = criteria.fileSizeMin {
            predicates.append("kMDItemFSSize >= \(minimum)")
        }
        if let maximum = criteria.fileSizeMax {
            predicates.append("kMDItemFSSize <= \(maximum)")
        }
        if predicates.isEmpty {
            predicates.append("kMDItemFSName != ''")
        }
        return predicates.map { "(\($0))" }.joined(separator: " && ")
    }

    private static func namePredicate(criteria: FindFilesCriteria) -> String? {
        let patterns = criteria.fileNamePattern
            .split(separator: ";", omittingEmptySubsequences: true)
            .map { escape(String($0)) }
        let effectivePatterns = patterns.isEmpty ? ["*"] : patterns
        if effectivePatterns == ["*"] {
            return nil
        }
        let modifier = criteria.caseSensitive ? "" : "c"
        return effectivePatterns
            .map { "kMDItemFSName == '\($0)'\(modifier)" }
            .map { "(\($0))" }
            .joined(separator: " || ")
    }

    private static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
    }
}
