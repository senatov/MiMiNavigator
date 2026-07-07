// MultiRenameModels.swift
// MiMiNavigator

import Foundation

// MARK: - Multi Rename Scope
enum MultiRenameScope: String, CaseIterable, Identifiable {
    case selection = "Selection"
    case directory = "Entire Directory"
    var id: String { rawValue }
}

// MARK: - Multi Rename Case Mode
enum MultiRenameCaseMode: String, CaseIterable, Identifiable {
    case unchanged = "Unchanged"
    case lowercase = "lowercase"
    case uppercase = "UPPERCASE"
    case capitalized = "Capitalize Words"
    var id: String { rawValue }
}

// MARK: - Multi Rename Rule
struct MultiRenameRule: Sendable {
    var nameMask = "[N]"
    var extensionMask = "[E]"
    var searchText = ""
    var replacementText = ""
    var useRegex = false
    var caseSensitive = false
    var counterStart = 1
    var counterStep = 1
    var counterDigits = 1
    var caseMode = MultiRenameCaseMode.unchanged
}

// MARK: - Multi Rename Source
struct MultiRenameSource: Identifiable, Hashable, Sendable {
    let url: URL
    let isDirectory: Bool
    var id: String { url.standardizedFileURL.path }
}

// MARK: - Multi Rename Preview Item
struct MultiRenamePreviewItem: Identifiable, Sendable {
    let source: MultiRenameSource
    let proposedName: String
    let issue: String?
    var id: String { source.id }
    var originalName: String { source.url.lastPathComponent }
    var destinationURL: URL { source.url.deletingLastPathComponent().appendingPathComponent(proposedName) }
    var isChanged: Bool { originalName != proposedName }
}

// MARK: - Multi Rename Result
struct MultiRenameResult: Sendable {
    let renamedCount: Int
}
