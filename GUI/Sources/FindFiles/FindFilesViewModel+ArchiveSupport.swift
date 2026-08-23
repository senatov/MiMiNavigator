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
        let payload = SavedSearchPayload(summary: lastSearchSummary, results: results)
        Task {
            do {
                try await FindFilesResultStore.shared.save(payload)
                log.info("[FindFiles] Saved \(payload.results.count) results")
            } catch {
                log.warning("[FindFiles] Save failed: \(error.localizedDescription)")
            }
        }
    }

    func loadSavedResults() {
        Task { @MainActor [weak self] in
            do {
                guard let payload = try await FindFilesResultStore.shared.load() else { return }
                self?.results = payload.results
                self?.lastSearchSummary = payload.summary
                self?.searchState = .completed
                log.info("[FindFiles] Loaded \(payload.results.count) saved results")
            } catch {
                log.warning("[FindFiles] Load failed: \(error.localizedDescription)")
            }
        }
    }

}
