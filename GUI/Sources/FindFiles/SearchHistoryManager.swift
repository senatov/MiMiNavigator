// SearchHistoryManager.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 14.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Manages search history for Find Files combo boxes — persisted in UserDefaults

import Foundation

// MARK: - Search History Manager
/// Stores up to 32 recent values per field, no duplicates, newest first
@MainActor
final class SearchHistoryManager {

    static let shared = SearchHistoryManager()

    // MARK: - History Keys
    enum HistoryKey: String {
        case fileNamePattern = "findFiles.history.fileNamePattern"
        case searchDirectory = "findFiles.history.searchDirectory"
        case searchText = "findFiles.history.searchText"
    }

    private let maxItems = 32
    private let defaults = UserDefaults.standard

    private init() {}

    // MARK: - Public API

    /// Get history for a key (newest first)
    func history(for key: HistoryKey) -> [String] {
        defaults.stringArray(forKey: key.rawValue) ?? []
    }

    /// Add a value to history (moves to top if exists, no duplicates)
    func add(_ value: String, for key: HistoryKey) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var items = history(for: key)

        // Remove duplicate if exists
        items.removeAll { $0 == trimmed }

        // Insert at top (newest first)
        items.insert(trimmed, at: 0)

        // Trim to max
        if items.count > maxItems {
            items = Array(items.prefix(maxItems))
        }

        defaults.set(items, forKey: key.rawValue)
        log.debug("[SearchHistory] Added '\(trimmed)' to \(key.rawValue), total: \(items.count)")
    }
}
