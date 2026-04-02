// ConflictResolution.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 23.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Enum representing possible conflict resolution actions

import Foundation

// MARK: - Conflict Resolution Options
/// Represents user's choice when a file naming conflict occurs.
/// Windows-style: per-file decision + "apply to all remaining" batch flag.
enum ConflictResolution: Equatable {
    /// skip the conflicting file, keep existing
    case skip
    /// keep both — rename incoming with suffix
    case keepBoth
    /// replace existing with incoming
    case replace
    /// stop the entire batch operation
    case stop
}


/// Wraps a resolution + "apply to all" flag for batch file ops.
/// When applyToAll is true, subsequent conflicts reuse the same resolution
/// without showing the dialog again.
struct BatchConflictDecision: Equatable {
    let resolution: ConflictResolution
    let applyToAll: Bool
}
