    // TabItem.swift
    // MiMiNavigator
    //
    // Created by Claude on 14.02.2026.
    // Copyright © 2026 Senatov. All rights reserved.
    // Description: Model for a single tab in a file panel — stores directory URL, display name, and archive context

    import Foundation

    // MARK: - Tab Item
    /// Represents a single tab within a panel.
    /// Each tab has its own directory URL, display name (macOS-standard truncation),
    /// and optional archive navigation state.
    struct TabItem: Identifiable, Codable, Equatable, Sendable {

        // MARK: - Properties

        let id: UUID
        var url: URL

        /// Archive URL if this tab is viewing inside an archive
        var archiveURL: URL?

        /// True if this tab represents an archive view
        var isArchive: Bool {
            archiveURL != nil
        }

        // MARK: - Init

        init(
            id: UUID = UUID(),
            url: URL,
            archiveURL: URL? = nil
        ) {
            self.id = id
            self.url = url.standardizedFileURL
            self.archiveURL = archiveURL?.standardizedFileURL
        }

        // MARK: - Display Name

        /// Returns macOS-standard abbreviated display name for the tab title.
        /// Uses FileManager.displayName for the last path component,
        /// consistent with Finder's tab naming convention.
        var displayName: String {
            FileManager.default.displayName(atPath: url.path)
        }

        /// Parent folder name used as a hint when multiple tabs share the same displayName
        /// Example: "Downloads" for "/Users/me/Downloads/Images"
        var parentFolderName: String? {
            let parent = url.deletingLastPathComponent()
            let name = parent.lastPathComponent
            return name.isEmpty ? nil : name
        }

        /// Optional extended title that includes parent context.
        /// Useful when several tabs have identical names.
        /// Example: "Images — Downloads"
        var contextualTitle: String {
            if let parent = parentFolderName, parent != displayName {
                return "\(displayName) — \(parent)"
            }
            return displayName
        }

        /// Returns a middle‑truncated version of `displayName`.
        /// macOS commonly truncates titles in the middle using an ellipsis
        /// so that both the beginning and the end of the name remain visible.
        /// This mimics Finder / tab title behavior.
        func truncatedDisplayName(maxLength: Int = 32) -> String {

            let name = displayName
            guard name.count > maxLength else { return name }

            let ellipsis = "…"

            // Characters to keep on each side
            let side = max((maxLength - ellipsis.count) / 2, 1)

            let prefixPart = name.prefix(side)
            let suffixPart = name.suffix(side)

            return "\(prefixPart)\(ellipsis)\(suffixPart)"
        }
    }

    // MARK: - Convenience Factory

    extension TabItem {

        /// Create a tab for a regular directory
        static func directory(url: URL) -> TabItem {
            TabItem(url: url)
        }

        /// Create a tab for an archive opened as virtual directory
        static func archive(extractedURL: URL, archiveURL: URL) -> TabItem {
            TabItem(url: extractedURL, archiveURL: archiveURL)
        }
    }
