// ParentDirectoryEntry.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 11.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Synthetic ".." parent directory entry displayed at the top of every file panel

import Foundation

// MARK: - Parent Directory Entry Factory
/// Creates a synthetic CustomFile representing ".." (parent directory navigation).
/// This entry is always the first row in every file panel list.
enum ParentDirectoryEntry {

    /// Sentinel ID used to identify the ".." row everywhere in the code
    static let id = "__..__parent_directory_sentinel__"

    /// Create a synthetic ".." entry for the given current directory path.
    /// - Parameter currentPath: The path of the directory currently displayed in the panel
    /// - Returns: A CustomFile representing ".." with parent directory as its path
    static func make(for currentPath: String) -> CustomFile {
        let currentURL = URL(fileURLWithPath: currentPath)
        let parentURL = currentURL.deletingLastPathComponent()
        return CustomFile(name: "..", path: parentURL.path)
    }

    /// Check if a CustomFile is the synthetic ".." parent directory entry
    static func isParentEntry(_ file: CustomFile) -> Bool {
        file.nameStr == ".."
    }

    /// Check if a file ID corresponds to the ".." entry
    static func isParentEntryID(_ fileID: String) -> Bool {
        fileID == id
    }
}
