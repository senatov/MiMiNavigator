// ArchiveNavigationState.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 11.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Per-panel state tracking for archive virtual directory navigation

import Foundation

// MARK: - Archive Navigation State
/// Tracks whether a panel is currently browsing inside an extracted archive.
/// Each panel (left/right) has its own instance.
struct ArchiveNavigationState: Sendable, Equatable {
    /// Whether the panel is currently inside an archive virtual directory
    var isInsideArchive: Bool = false

    /// Path to the original archive file (e.g., /Users/.../data.zip)
    var archiveURL: URL? = nil

    /// Path to the extracted temp directory (e.g., /tmp/MiMiNavigator_archives/<UUID>/)
    var archiveTempDir: URL? = nil

    /// The directory that contains the archive (for navigating out)
    var archiveParentDir: URL? {
        archiveURL?.deletingLastPathComponent()
    }

    // MARK: - Enter Archive
    mutating func enterArchive(archiveURL: URL, tempDir: URL) {
        self.isInsideArchive = true
        self.archiveURL = archiveURL
        self.archiveTempDir = tempDir
        log.info("[ArchiveNavState] Entered archive: \(archiveURL.lastPathComponent) → \(tempDir.path)")
    }

    // MARK: - Exit Archive
    mutating func exitArchive() {
        log.info("[ArchiveNavState] Exiting archive: \(archiveURL?.lastPathComponent ?? "?")")
        self.isInsideArchive = false
        self.archiveURL = nil
        self.archiveTempDir = nil
    }

    // MARK: - Check if path is at archive root level
    /// Returns true if the current panel path is the root of the extracted archive
    /// (i.e., ".." should navigate OUT of the archive, not up within it)
    func isAtArchiveRoot(currentPath: String) -> Bool {
        guard isInsideArchive, let tempDir = archiveTempDir else { return false }
        let normalizedCurrent = URL(fileURLWithPath: currentPath).standardizedFileURL.path
        let normalizedTemp = tempDir.standardizedFileURL.path
        return normalizedCurrent == normalizedTemp
    }
}

// MARK: - Archive File Extensions
/// Centralized set of recognized archive extensions
enum ArchiveExtensions {
    static let all: Set<String> = [
        "zip", "7z", "tar", "gz", "bz2", "tgz", "rar",
        "xz", "lzma", "lz4", "zst"
    ]

    /// Check if a file extension is a recognized archive format
    static func isArchive(_ ext: String) -> Bool {
        all.contains(ext.lowercased())
    }

    /// Check if a filename has a compound archive extension (e.g., .tar.gz)
    static func isCompoundArchive(_ filename: String) -> Bool {
        let lower = filename.lowercased()
        return lower.hasSuffix(".tar.gz")
            || lower.hasSuffix(".tar.bz2")
            || lower.hasSuffix(".tar.xz")
            || lower.hasSuffix(".tar.lzma")
            || lower.hasSuffix(".tar.zst")
    }
}
