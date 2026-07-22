// DiffToolScope.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 24.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Supported comparison scopes for external diff tools.

import Foundation

// MARK: - Diff Tool Scope
enum DiffToolScope: String, Codable, CaseIterable, Identifiable {
    case filesOnly = "files"
    case dirsOnly = "dirs"
    case both = "both"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .filesOnly: "Files only"
        case .dirsOnly: "Directories only"
        case .both: "Files & Dirs"
        }
    }
}
