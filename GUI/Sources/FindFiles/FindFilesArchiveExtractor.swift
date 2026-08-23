// FindFilesArchiveExtractor.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Archive extraction with progress presentation for Find Files results.

import Foundation

// MARK: - Find Files Archive Extractor
@MainActor
enum FindFilesArchiveExtractor {
    // MARK: - Extract
    static func extract(_ archiveURL: URL) async throws -> URL {
        let progressPanel = ProgressPanel.shared
        let handle = ActiveArchiveProcess()
        progressPanel.show(
            archiveName: archiveURL.lastPathComponent,
            destinationPath: archiveURL.deletingLastPathComponent().path
        )
        progressPanel.appendLine("Extracting: \(archiveURL.lastPathComponent)")
        do {
            let directory = try await ArchiveManager.shared.openArchive(
                at: archiveURL,
                onProgress: { line in
                    Task { @MainActor in progressPanel.appendLine(line) }
                },
                processHandle: handle
            )
            progressPanel.finish(success: true)
            return directory
        } catch {
            progressPanel.finish(success: false, details: error.localizedDescription)
            throw error
        }
    }
}
