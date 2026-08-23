// FindFilesViewModel+ArchiveSupport.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Archive passwords, result persistence, and archive progress integration.

import FindFilesKit
import Foundation

// MARK: - Archive Password Handling
extension FindFilesViewModel {
    @Sendable
    func requestArchivePassword(archiveName: String) async -> ArchivePasswordResponse {
        await withCheckedContinuation { continuation in
            Task { @MainActor [weak self] in
                guard let self else {
                    continuation.resume(returning: .skip)
                    return
                }
                self.passwordArchiveName = archiveName
                self.archivePassword = ""
                self.passwordContinuation = continuation
                self.showPasswordDialog = true
            }
        }
    }

    func submitArchivePassword() {
        let password = archivePassword
        showPasswordDialog = false
        passwordContinuation?.resume(returning: .password(password))
        passwordContinuation = nil
    }

    func skipArchive() {
        showPasswordDialog = false
        passwordContinuation?.resume(returning: .skip)
        passwordContinuation = nil
    }

    // MARK: - Result Persistence
    func saveResults() {
        guard !results.isEmpty else { return }
        do {
            let payload = SavedSearchPayload(summary: lastSearchSummary, results: results)
            let data = try JSONEncoder().encode(payload)
            try data.write(to: Self.savedResultsURL, options: .atomic)
            log.info("[FindFiles] Saved \(results.count) results")
        } catch {
            log.warning("[FindFiles] Save failed: \(error.localizedDescription)")
        }
    }

    func loadSavedResults() {
        guard FileManager.default.fileExists(atPath: Self.savedResultsURL.path) else { return }
        do {
            let data = try Data(contentsOf: Self.savedResultsURL)
            let payload = try JSONDecoder().decode(SavedSearchPayload.self, from: data)
            results = payload.results
            lastSearchSummary = payload.summary
            searchState = .completed
            log.info("[FindFiles] Loaded \(results.count) saved results")
        } catch {
            log.warning("[FindFiles] Load failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Archive Progress
    func showArchiveProgress(for archiveURL: URL) -> (ProgressPanel, ActiveArchiveProcess) {
        let progressPanel = ProgressPanel.shared
        let handle = ActiveArchiveProcess()
        progressPanel.show(archiveName: archiveURL.lastPathComponent, destinationPath: archiveURL.deletingLastPathComponent().path)
        progressPanel.appendLine("Extracting: \(archiveURL.lastPathComponent)")
        return (progressPanel, handle)
    }

    func openArchiveWithProgress(_ archiveURL: URL, progressPanel: ProgressPanel, handle: ActiveArchiveProcess) async throws -> URL {
        try await ArchiveManager.shared.openArchive(
            at: archiveURL,
            onProgress: { line in
                Task { @MainActor in
                    progressPanel.appendLine(line)
                }
            },
            processHandle: handle
        )
    }
}
