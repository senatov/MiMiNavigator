// GitStatusSnapshot.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Read-only Git presentation models for file badges and directory summaries.

import Foundation

// MARK: - Git File State
enum GitFileState: Int, Sendable {
    case ignored = 0
    case modified = 1
    case untracked = 2
    case conflicted = 3

    var badge: String {
        switch self {
            case .modified: return "M"
            case .untracked: return "?"
            case .ignored: return "I"
            case .conflicted: return "!"
        }
    }

    var title: String {
        switch self {
            case .modified: return "Modified"
            case .untracked: return "Untracked"
            case .ignored: return "Ignored"
            case .conflicted: return "Conflicted"
        }
    }
}

// MARK: - Git Directory Summary
struct GitDirectorySummary: Equatable, Sendable {
    var modified = 0
    var untracked = 0
    var ignored = 0
    var conflicted = 0

    var isEmpty: Bool {
        modified == 0 && untracked == 0 && ignored == 0 && conflicted == 0
    }

    mutating func include(_ state: GitFileState) {
        switch state {
            case .modified: modified += 1
            case .untracked: untracked += 1
            case .ignored: ignored += 1
            case .conflicted: conflicted += 1
        }
    }
}

// MARK: - Git Status Snapshot
struct GitStatusSnapshot: Sendable {
    let repositoryRoot: URL
    let statesByRelativePath: [String: GitFileState]

    func state(for url: URL) -> GitFileState? {
        guard let relativePath = relativePath(for: url) else { return nil }
        var strongest = statesByRelativePath[relativePath]
        let prefix = relativePath.isEmpty ? "" : relativePath + "/"
        for (path, state) in statesByRelativePath where path.hasPrefix(prefix) {
            if strongest == nil || state.rawValue > strongest!.rawValue { strongest = state }
        }
        for (path, state) in statesByRelativePath where state == .ignored && relativePath.hasPrefix(path + "/") {
            if strongest == nil || state.rawValue > strongest!.rawValue { strongest = state }
        }
        return strongest
    }

    func summary(for directory: URL) -> GitDirectorySummary {
        guard let relativePath = relativePath(for: directory) else { return GitDirectorySummary() }
        let prefix = relativePath.isEmpty ? "" : relativePath + "/"
        var summary = GitDirectorySummary()
        for (path, state) in statesByRelativePath where path == relativePath || path.hasPrefix(prefix) {
            summary.include(state)
        }
        return summary
    }

    private func relativePath(for url: URL) -> String? {
        let rootPath = repositoryRoot.standardizedFileURL.path
        let filePath = url.standardizedFileURL.path
        guard filePath == rootPath || filePath.hasPrefix(rootPath + "/") else { return nil }
        if filePath == rootPath { return "" }
        return String(filePath.dropFirst(rootPath.count + 1))
    }
}
