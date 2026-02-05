// FileCache.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 07.11.24.
// Refactored: 27.01.2026
// Copyright © 2024-2026 Senatov. All rights reserved.
// Description: Thread-safe cache for file lists in dual-panel view

import Foundation

// MARK: - Thread-safe File Cache
/// Actor-based cache for storing scanned file lists for both panels.
/// Provides thread-safe access to file data across the application.
actor FileCache {
    static let shared = FileCache()
    
    private var _leftFiles: [CustomFile] = []
    private var _rightFiles: [CustomFile] = []

    // MARK: - Update left panel files
    func updateLeftFiles(_ files: [CustomFile]) {
        _leftFiles = files
    }

    // MARK: - Update right panel files
    func updateRightFiles(_ files: [CustomFile]) {
        _rightFiles = files
    }

    // MARK: - Get left panel files
    func getLeftFiles() -> [CustomFile] {
        _leftFiles
    }

    // MARK: - Get right panel files
    func getRightFiles() -> [CustomFile] {
        _rightFiles
    }
    
    // MARK: - Clear all cached files
    func clearAll() {
        _leftFiles = []
        _rightFiles = []
    }
}

