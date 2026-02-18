// ArchiveFormatDetector.swift
// MiMiNavigator
//
// Extracted from ArchiveManager.swift on 12.02.2026
// Copyright © 2026 Senatov. All rights reserved.
// Description: Detects archive format from file extension — maps to ArchiveFormat enum

import Foundation

// MARK: - Archive Format Detector
/// Determines the ArchiveFormat for a given file URL based on extension and compound names.
enum ArchiveFormatDetector {

    /// Detect archive format from URL. Returns nil if not a recognized archive.
    static func detect(url: URL) -> ArchiveFormat? {
        let ext = url.pathExtension.lowercased()
        let name = url.lastPathComponent.lowercased()

        // Compound tar extensions first (order matters — check before single extension)
        if name.hasSuffix(".tar.gz") || ext == "tgz" { return .tarGz }
        if name.hasSuffix(".tar.bz2") || ext == "tbz" || ext == "tbz2" { return .tarBz2 }
        if name.hasSuffix(".tar.xz") || ext == "txz" { return .tarXz }
        if name.hasSuffix(".tar.lzma") || ext == "tlz" { return .tarLzma }
        if name.hasSuffix(".tar.zst") { return .tarZst }
        if name.hasSuffix(".tar.lz4") { return .tarLz4 }
        if name.hasSuffix(".tar.lzo") { return .tarLzo }
        if name.hasSuffix(".tar.lz") { return .tarLz }

        switch ext {
        // Native macOS tools
        case "zip": return .zip
        case "tar": return .tar
        case "gz", "gzip": return .tarGz
        case "bz2", "bzip2": return .tarBz2
        case "xz": return .tarXz
        case "lzma": return .tarLzma
        case "z": return .compressZ

        // 7z native
        case "7z": return .sevenZip

        // 7z handles all of these
        case "rar", "cab", "arj", "lha", "lzh",
             "rpm", "deb", "cpio", "xar",
             "iso", "img", "vhd", "vmdk",
             "wim", "swm",
             "dmg", "pkg",
             "jar", "war", "ear", "aar", "apk",
             "lz4", "zst", "zstd",
             "ace", "sit", "sitx",
             "squashfs", "cramfs",
             "lz", "lzo":
            return .sevenZipGeneric

        default:
            if ArchiveExtensions.isArchive(ext) { return .sevenZipGeneric }
            return nil
        }
    }
}
