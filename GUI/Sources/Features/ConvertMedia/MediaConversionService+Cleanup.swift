// MediaConversionService+Cleanup.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Recoverable cleanup for media conversion artifacts.

import Foundation

// MARK: - Media Conversion Cleanup

@MainActor
extension MediaConversionService {
    // MARK: - Recycle Conversion Artifact
    func recycleConversionArtifactLater(_ url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        Task {
            do {
                _ = try await FileRecycleService.recycle(url)
                log.debug("[MediaConvert] recycled service artifact '\(url.lastPathComponent)'")
            } catch {
                log.warning(
                    "[MediaConvert] recycle failed path=\(url.path.debugDescription) " +
                    "error=\(error.localizedDescription.debugDescription); artifact preserved"
                )
            }
        }
    }
}
