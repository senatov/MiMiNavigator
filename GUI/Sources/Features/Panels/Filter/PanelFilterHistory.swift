// PanelFilterHistory.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 19.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Persistent filter history (up to 16 entries) per panel, saved in UserDefaults

import Foundation

// MARK: - Filter history storage (max 16, chronological, no duplicates)
final class PanelFilterHistory: ObservableObject {
    static let maxEntries = 16

    private let key: String
    @Published private(set) var entries: [String] = []

    init(panelSide: String) {
        self.key = "panelFilterHistory.\(panelSide)"
        self.entries = Self.load(key: key)
    }

    // MARK: - Add entry (moves to top if exists, trims to maxEntries)
    func add(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        var updated = entries.filter { $0 != trimmed }
        updated.insert(trimmed, at: 0)
        if updated.count > Self.maxEntries { updated = Array(updated.prefix(Self.maxEntries)) }
        entries = updated
        save()
    }

    // MARK: - Remove single entry
    func remove(_ query: String) {
        entries.removeAll { $0 == query }
        save()
    }

    // MARK: - Persistence
    private func save() {
        UserDefaults.standard.set(entries, forKey: key)
    }

    private static func load(key: String) -> [String] {
        UserDefaults.standard.stringArray(forKey: key) ?? []
    }
}
