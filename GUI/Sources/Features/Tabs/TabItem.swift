// TabItem.swift
// MiMiNavigator
//
// Created by Claude on 14.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Model for a single tab in a file panel — stores path, display name, and archive context

import Foundation

// MARK: - Tab Item
/// Represents a single tab within a panel.
/// Each tab has its own directory path, display name (macOS-standard truncation),
/// and optional archive navigation state.
struct TabItem: Identifiable, Codable, Equatable, Sendable {

    // MARK: - Properties

    let id: UUID
    var path: String
    var isArchive: Bool

    /// Archive URL if this tab is viewing inside an archive
    var archiveURL: URL?

    // MARK: - Init

    init(
        id: UUID = UUID(),
        path: String,
        isArchive: Bool = false,
        archiveURL: URL? = nil
    ) {
        self.id = id
        self.path = path
        self.isArchive = isArchive
        self.archiveURL = archiveURL
    }

    // MARK: - Display Name

    /// Returns macOS-standard abbreviated display name for the tab title.
    /// Uses FileManager.displayName for the last path component,
    /// consistent with Finder's tab naming convention.
    var displayName: String {
        let url = URL(fileURLWithPath: path)
        let name = FileManager.default.displayName(atPath: url.path)
        return name
    }

    /// Short display name truncated to maxLength with ellipsis (macOS style).
    /// Uses middle truncation like Finder: "Very Long Dir…Name"
    func truncatedDisplayName(maxLength: Int = 20) -> String {
        let name = displayName
        guard name.count > maxLength else { return name }

        // macOS-standard middle truncation
        let headLength = (maxLength - 1) / 2
        let tailLength = maxLength - 1 - headLength
        let head = name.prefix(headLength)
        let tail = name.suffix(tailLength)
        return "\(head)…\(tail)"
    }
}

// MARK: - Convenience Factory

extension TabItem {

    /// Create a tab for a regular directory
    static func directory(path: String) -> TabItem {
        TabItem(path: path, isArchive: false)
    }

    /// Create a tab for an archive opened as virtual directory
    static func archive(extractedPath: String, archiveURL: URL) -> TabItem {
        TabItem(path: extractedPath, isArchive: true, archiveURL: archiveURL)
    }
}
