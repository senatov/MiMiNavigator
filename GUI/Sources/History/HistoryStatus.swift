// HistoryStatus.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 28.09.2024.
// Renamed: 13.02.2026 — Status → HistoryStatus, moved to States/History
// Copyright © 2024-2026 Senatov. All rights reserved.

import Foundation

// MARK: - History entry status
enum HistoryStatus: String, Codable {
    case added
    case modified
    case deleted
}

// MARK: - Type alias for backward compatibility
typealias Status = HistoryStatus
