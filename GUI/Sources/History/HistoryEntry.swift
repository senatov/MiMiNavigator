// HistoryEntry.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 28.09.2024.
// Moved: 13.02.2026 — from Primitives to States/History
// Copyright © 2024-2026 Senatov. All rights reserved.

import Foundation

// MARK: - History entry for navigation tracking
struct HistoryEntry: Codable, Equatable {
    var path: String
    var timestamp: Date
    var status: HistoryStatus
    var snapshot: FileSnapshot?

    static func == (lhs: HistoryEntry, rhs: HistoryEntry) -> Bool { 
        lhs.path == rhs.path 
    }
}
