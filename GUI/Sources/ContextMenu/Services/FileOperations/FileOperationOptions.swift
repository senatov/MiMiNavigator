// FileOperationOptions.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 27.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Options for file copy/move operations

import Foundation

// MARK: - File Operation Options
/// Configuration options for copy/move operations
struct FileOperationOptions {
    var conflictResolution: ConflictResolution = .keepBoth
    var applyToAll: Bool = false
    
    static let `default` = FileOperationOptions()
}
