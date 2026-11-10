// JunkScanTypes.swift
// MiMiNavigator
// Copyright © 2026 Senatov. All rights reserved.

import Foundation

// MARK: - Cleanup Candidate
struct JunkCandidate: Identifiable, Sendable, Codable {
    enum Kind: String, Sendable, Codable {
        case duplicate = "Duplicate"
        case duplicateFolder = "Duplicate folder"
        case emptyFolder = "Empty folder"
        case oldInstaller = "Old installer"
        case temporary = "Temporary file"
        case appLeftover = "App leftover"
        case processArtifact = "Stale process file"
        case browserCache = "Browser cache"
        case browserPrivacy = "Browser activity and site data"
        case appCache = "Application cache"
        case developerCache = "Developer cache"
    }
    var reviewLevel: String {
        switch kind {
        case .browserPrivacy, .appLeftover: "Sensitive — check first"
        case .oldInstaller, .appCache, .developerCache: "Check first"
        case .duplicate, .duplicateFolder: "Keep one copy"
        case .emptyFolder: "Empty folder"
        case .temporary, .processArtifact, .browserCache: "Stale item"
        }
    }
    let url: URL
    let kind: Kind
    let reason: String
    let size: Int64
    let group: String?
    var modified: Date? = nil
    var id: String { url.path }
    var name: String { url.lastPathComponent }
    var location: String { url.deletingLastPathComponent().path }
    var sortableDate: Date { modified ?? .distantPast }
}

// MARK: - Scan Progress
struct JunkScanProgress: Sendable {
    let visited: Int
    let candidates: [JunkCandidate]
    let diagnostics: JunkScanDiagnostics
}

// MARK: - Scan Diagnostics
struct JunkScanDiagnostics: Sendable {
    var inaccessiblePaths = 0
    var unreadablePaths = 0
    var summary: String {
        [inaccessiblePaths > 0 ? "\(inaccessiblePaths) paths skipped by access or safety rules" : nil,
         unreadablePaths > 0 ? "\(unreadablePaths) paths could not be read" : nil]
            .compactMap { $0 }.joined(separator: " · ")
    }
}

// MARK: - Persistent Traversal Record
struct JunkFileRecord: Sendable {
    let url: URL
    let size: Int64
    let modified: Date
}

// MARK: - Directory Checkpoint
struct JunkDirectoryBatch: Sendable {
    let directory: URL
    let childDirectories: [URL]
    let files: [JunkFileRecord]
    let candidates: [JunkCandidate]
    let visited: Int
    var diagnostics = JunkScanDiagnostics()
}
