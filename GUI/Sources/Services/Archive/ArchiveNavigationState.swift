// ArchiveNavigationState.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 11.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Per-panel state for archive virtual directory navigation

import Foundation

// MARK: - Archive Navigation State
struct ArchiveNavigationState: Sendable, Equatable {

    var isInsideArchive: Bool = false
    var archiveURL: URL?       = nil
    var archiveTempDir: URL?   = nil

    var archiveParentDir: URL? { archiveURL?.deletingLastPathComponent() }

    mutating func enterArchive(archiveURL: URL, tempDir: URL) {
        isInsideArchive = true
        self.archiveURL = archiveURL
        self.archiveTempDir = tempDir
    }

    mutating func exitArchive() {
        isInsideArchive = false
        archiveURL      = nil
        archiveTempDir  = nil
    }

    /// True when panel is at the extracted root — ".." should leave the archive
    func isAtArchiveRoot(currentPath: String) -> Bool {
        guard isInsideArchive, let tempDir = archiveTempDir else { return false }
        return URL(fileURLWithPath: currentPath).standardizedFileURL.path
            == tempDir.standardizedFileURL.path
    }
}
