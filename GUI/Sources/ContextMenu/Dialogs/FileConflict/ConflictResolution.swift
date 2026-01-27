// ConflictResolution.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 23.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Enum representing possible conflict resolution actions

import Foundation

// MARK: - Conflict Resolution Options
/// Represents user's choice when a file naming conflict occurs
enum ConflictResolution: Equatable {
    /// Skip the conflicting file, keep the existing one
    case skip
    /// Keep both files by renaming the source
    case keepBoth
    /// Replace the existing file with the source
    case replace
    /// Stop the entire operation
    case stop
}
