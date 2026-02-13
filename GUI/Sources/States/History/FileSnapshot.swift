// FileSnapshot.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 28.09.2024.
// Moved: 13.02.2026 — from Primitives to States/History
// Copyright © 2024-2026 Senatov. All rights reserved.

import Foundation

// MARK: - File state snapshot for change detection
/// Used by HistoryEntry to track file modifications
struct FileSnapshot: Codable, Equatable {
    var size: Int64
    var mtime: Date?
}
