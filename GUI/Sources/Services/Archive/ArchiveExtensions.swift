// ArchiveExtensions.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 12.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Centralized registry of recognized archive file extensions

// MARK: - Archive Extensions
enum ArchiveExtensions {

    static let all: Set<String> = [
        "zip", "7z", "rar", "tar",
        "gz", "tgz", "gzip",
        "bz2", "bzip2", "tbz", "tbz2",
        "xz", "txz", "lzma", "tlz",
        "lz4", "zst", "zstd", "lz", "lzo",
        "cab", "arj", "cpio", "rpm", "deb",
        "dmg", "pkg", "xar",
        "jar", "war", "ear", "aar", "apk",
        "iso", "img", "vhd", "vmdk",
        "wim", "swm", "squashfs", "cramfs",
        "z", "Z", "lha", "lzh",
        "ace", "sit", "sitx",
    ]

    static func isArchive(_ ext: String) -> Bool {
        all.contains(ext.lowercased())
    }

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

    static let categories: [(group: String, extensions: [String])] = [
        ("Standard",       ["zip", "7z", "rar", "tar"]),
        ("Gzip",           ["gz", "tgz", "tar.gz"]),
        ("Bzip2",          ["bz2", "tbz2", "tar.bz2"]),
        ("XZ/LZMA",        ["xz", "txz", "lzma", "tar.xz"]),
        ("Modern",         ["zst", "lz4", "lzo", "lz"]),
        ("Package/System", ["cab", "rpm", "deb", "cpio", "xar"]),
        ("macOS",          ["dmg", "pkg"]),
        ("Java/Android",   ["jar", "war", "ear", "aar", "apk"]),
        ("Disk Images",    ["iso", "img", "vhd", "vmdk"]),
        ("Legacy",         ["arj", "lha", "lzh", "ace", "sit", "sitx", "z", "Z"]),
        ("Filesystem",     ["wim", "squashfs", "cramfs"]),
    ]
}
