// FindFilesSystemActions.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Workspace, clipboard, and export actions for Find Files results.

import AppKit
import FindFilesKit
import Foundation

// MARK: - Find Files System Actions
@MainActor
enum FindFilesSystemActions {
    static func open(_ result: FindFilesResult) {
        NSWorkspace.shared.open(actionURL(for: result))
    }

    static func reveal(_ result: FindFilesResult) {
        NSWorkspace.shared.activateFileViewerSelecting([actionURL(for: result)])
    }

    static func copyPaths(_ results: [FindFilesResult]) {
        let value = results.map(\.filePath).joined(separator: "\n")
        guard !value.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }

    private static func actionURL(for result: FindFilesResult) -> URL {
        result.archivePath.map { URL(fileURLWithPath: $0) } ?? result.fileURL
    }
}

// MARK: - Find Files Export Writer
actor FindFilesExportWriter {
    static let shared = FindFilesExportWriter()

    func write(results: [FindFilesResult], summary: String, to url: URL) throws {
        let date = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short)
        var lines = [
            "MiMiNavigator — Search Results",
            "Date: \(date)",
            "Query: \(summary)",
            "Found: \(results.count) file(s)",
            String(repeating: "-", count: 60),
            ""
        ]
        for result in results {
            var line = result.filePath
            if let context = result.matchContext, let lineNumber = result.lineNumber {
                line += ":\(lineNumber): \(context)"
            }
            if let archive = result.archivePath { line = "[\(archive)] \(line)" }
            lines.append(line)
        }
        try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
    }
}
