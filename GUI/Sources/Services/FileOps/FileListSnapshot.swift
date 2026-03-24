// FileListSnapshot.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 27.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Versioned wrapper for file lists.
//   Equatable comparison uses only the version counter — O(1) instead of O(n).
//   SwiftUI onChange(of:) and @Observable diffing never touch the file array itself.

import FileModelKit

// MARK: - File List Snapshot

struct FileListSnapshot: Equatable, Sendable {
    // MARK: - Content
    let files: [CustomFile]
    // MARK: - Version counter — monotonically increasing, used for O(1) equality check
    let version: Int

    // MARK: - Init
    init(files: [CustomFile], version: Int) {
        self.files = files
        self.version = version
    }

    // MARK: - Equatable — compare version only, never the array
    static func == (lhs: FileListSnapshot, rhs: FileListSnapshot) -> Bool {
        lhs.version == rhs.version
    }

    // MARK: - Empty snapshot
    static let empty = FileListSnapshot(files: [], version: 0)
}
