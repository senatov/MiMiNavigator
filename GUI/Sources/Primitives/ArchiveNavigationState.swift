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
    /// All recognized single-extension archive formats.
    /// Extraction is handled by ArchiveManager using appropriate CLI tools.
    static let all: Set<String> = [
        // Standard compressed archives
        "zip", "7z", "rar", "tar",
        // Gzip family
        "gz", "tgz", "gzip",
        // Bzip2 family
        "bz2", "bzip2", "tbz", "tbz2",
        // XZ / LZMA family
        "xz", "txz", "lzma", "tlz",
        // Modern compression
        "lz4", "zst", "zstd", "lz", "lzo",
        // Less common but supported by 7z
        "cab", "arj", "cpio", "rpm", "deb",
        // macOS / iOS specific
        "dmg", "pkg", "xar",
        // Java / Android
        "jar", "war", "ear", "aar", "apk",
        // Disk images and ISOs
        "iso", "img", "vhd", "vmdk",
        // Other
        "wim", "swm", "squashfs", "cramfs",
        "z", "Z", "lha", "lzh",
        "ace", "sit", "sitx",
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
            || lower.hasSuffix(".tar.lz4")
            || lower.hasSuffix(".tar.lzo")
            || lower.hasSuffix(".tar.lz")
    }

    /// Format categories for documentation / UI display
    static let categories: [(group: String, extensions: [String])] = [
        ("Standard",      ["zip", "7z", "rar", "tar"]),
        ("Gzip",          ["gz", "tgz", "tar.gz"]),
        ("Bzip2",         ["bz2", "tbz2", "tar.bz2"]),
        ("XZ/LZMA",       ["xz", "txz", "lzma", "tar.xz"]),
        ("Modern",        ["zst", "lz4", "lzo", "lz"]),
        ("Package/System",["cab", "rpm", "deb", "cpio", "xar"]),
        ("macOS",         ["dmg", "pkg"]),
        ("Java/Android",  ["jar", "war", "ear", "aar", "apk"]),
        ("Disk Images",   ["iso", "img", "vhd", "vmdk"]),
        ("Legacy",        ["arj", "lha", "lzh", "ace", "sit", "sitx", "z", "Z"]),
        ("Filesystem",    ["wim", "squashfs", "cramfs"]),
    ]
}
