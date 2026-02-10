// FindFilesL10n.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 10.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Localization strings for Find Files module

import Foundation

// MARK: - Find Files Localization
extension L10n {
    enum FindFiles {
        // Panel
        static let title = String(localized: "Find Files", comment: "Find files panel title")
        static let close = String(localized: "Close", comment: "Close button")

        // Tabs
        static let generalTab = String(localized: "General", comment: "General tab")
        static let advancedTab = String(localized: "Advanced", comment: "Advanced tab")

        // General tab
        static let searchFor = String(localized: "Search for:", comment: "File name pattern label")
        static let searchIn = String(localized: "Search in:", comment: "Search directory label")
        static let findText = String(localized: "Find text:", comment: "Content search label")
        static let caseSensitive = String(localized: "Case sensitive", comment: "Case sensitive toggle")
        static let regex = String(localized: "Regex", comment: "Regex toggle")
        static let subdirectories = String(localized: "Subdirectories", comment: "Subdirectories toggle")
        static let searchInArchives = String(localized: "Search in archives", comment: "Archives toggle")

        // Advanced tab
        static let filterBySize = String(localized: "Filter by size", comment: "Size filter toggle")
        static let filterByDate = String(localized: "Filter by date", comment: "Date filter toggle")
        static let from = String(localized: "From:", comment: "From label")
        static let to = String(localized: "To:", comment: "To label")

        // Results
        static let noResults = String(localized: "No files found", comment: "No results message")
        static let goToFile = String(localized: "Go to File", comment: "Go to file action")
        static let open = String(localized: "Open", comment: "Open file action")
        static let revealInFinder = String(localized: "Reveal in Finder", comment: "Reveal in finder action")
        static let copyPath = String(localized: "Copy Path", comment: "Copy path action")
        static let copyAllPaths = String(localized: "Copy All Paths", comment: "Copy all paths action")
        static let exportResults = String(localized: "Export Results…", comment: "Export results action")

        // Status
        static let ready = String(localized: "Ready", comment: "Search ready status")
        static let searching = String(localized: "Searching…", comment: "Searching status")
        static let cancelled = String(localized: "Cancelled", comment: "Search cancelled status")
        static let newSearch = String(localized: "New Search", comment: "New search button")
        static let search = String(localized: "Search", comment: "Search button")

        // Archive password
        static let passwordRequired = String(localized: "Password Required", comment: "Password dialog title")
        static let archiveProtected = String(localized: "The archive is password-protected:", comment: "Archive protected message")
        static let enterPassword = String(localized: "Enter password…", comment: "Password placeholder")
        static let skipArchive = String(localized: "Skip Archive", comment: "Skip archive button")

        // Pattern help
        static let patternHelp = String(localized: "File Name Pattern Syntax", comment: "Pattern help title")

        // Statistics
        static func found(_ count: Int) -> String {
            String(localized: "\(count) found", comment: "Found count")
        }
        static func filesScanned(_ count: Int) -> String {
            String(localized: "\(count) files scanned", comment: "Files scanned count")
        }
    }
}
