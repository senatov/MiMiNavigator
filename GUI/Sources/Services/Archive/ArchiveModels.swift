// ArchiveModels.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 12.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Value types shared across the Archive layer

import Foundation

// MARK: - Archive Format
enum ArchiveFormat: String, CaseIterable, Identifiable, Sendable {
    case zip          = "zip"
    case tarGz        = "tar.gz"
    case tarBz2       = "tar.bz2"
    case tarXz        = "tar.xz"
    case tarLzma      = "tar.lzma"
    case tarZst       = "tar.zst"
    case tarLz4       = "tar.lz4"
    case tarLzo       = "tar.lzo"
    case tarLz        = "tar.lz"
    case tar          = "tar"
    case compressZ    = "Z"
    case sevenZip     = "7z"
    case sevenZipGeneric = "7z-generic"

    var id: String { rawValue }
    var fileExtension: String { rawValue }

    var displayName: String {
        switch self {
        case .zip:              return "ZIP Archive"
        case .tarGz:            return "TAR.GZ (gzip)"
        case .tarBz2:           return "TAR.BZ2 (bzip2)"
        case .tarXz:            return "TAR.XZ (xz)"
        case .tarLzma:          return "TAR.LZMA"
        case .tarZst:           return "TAR.ZST (zstandard)"
        case .tarLz4:           return "TAR.LZ4"
        case .tarLzo:           return "TAR.LZO"
        case .tarLz:            return "TAR.LZ (lzip)"
        case .tar:              return "TAR (uncompressed)"
        case .compressZ:        return "Unix Compress (.Z)"
        case .sevenZip:         return "7-Zip Archive"
        case .sevenZipGeneric:  return "Archive (via 7z)"
        }
    }

    var icon: String {
        switch self {
        case .zip:              return "doc.zipper"
        case .sevenZip, .sevenZipGeneric: return "archivebox.fill"
        default:                return "archivebox"
        }
    }

    var isAvailable: Bool {
        switch self {
        case .zip, .tar, .tarGz, .tarBz2, .tarXz, .compressZ,
             .tarLzma, .tarZst, .tarLz4, .tarLzo, .tarLz:
            return true
        case .sevenZip, .sevenZipGeneric:
            return ["/usr/local/bin/7z", "/opt/homebrew/bin/7z", "/usr/bin/7z"]
                .contains { FileManager.default.fileExists(atPath: $0) }
        }
    }

    static var availableFormats: [ArchiveFormat] { allCases.filter(\.isAvailable) }
}

// MARK: - Archive Session
/// Runtime state of a single opened archive tracked by ArchiveManager
struct ArchiveSession: Sendable {
    let archiveURL: URL
    let tempDirectory: URL
    let format: ArchiveFormat
    var isDirty: Bool
    let originalPosixPermissions: Int16
    let originalModificationDate: Date?
    let originalCreationDate: Date?
    let originalOwnerName: String

    /// Snapshot of relative-path → mtime taken immediately after extraction.
    /// Used by scanForChanges() to detect real user edits vs extraction artifacts.
    let baselineSnapshot: [String: Date]
}
