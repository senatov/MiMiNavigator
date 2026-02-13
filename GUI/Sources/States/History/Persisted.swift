// Persisted.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 28.09.2024.
// Moved: 13.02.2026 — from Primitives to States/History
// Copyright © 2024-2026 Senatov. All rights reserved.

import Foundation

// MARK: - Persisted history state
/// Used for saving/loading SelectionsHistory to UserDefaults
struct Persisted: Codable {
    var entries: [HistoryEntry]
    var currentIndex: Int?
}
