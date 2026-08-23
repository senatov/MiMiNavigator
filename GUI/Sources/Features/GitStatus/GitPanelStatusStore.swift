// GitPanelStatusStore.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Main-actor Git status presentation cache shared by both file panels.

import Foundation

// MARK: - Git Panel Status Store
@MainActor
@Observable
final class GitPanelStatusStore {
    static let shared = GitPanelStatusStore()

    private var snapshotsByDirectory: [String: GitStatusSnapshot] = [:]
    private let provider: any GitStatusProviding

    private init(provider: any GitStatusProviding = GitStatusService.shared) {
        self.provider = provider
    }

    func refresh(directory: URL) async {
        let key = directory.standardizedFileURL.path
        let snapshot = await provider.snapshot(for: directory)
        guard !Task.isCancelled else { return }
        snapshotsByDirectory[key] = snapshot
    }

    func state(for url: URL, in directory: URL) -> GitFileState? {
        snapshotsByDirectory[directory.standardizedFileURL.path]?.state(for: url)
    }

    func summary(for directory: URL) -> GitDirectorySummary? {
        guard let snapshot = snapshotsByDirectory[directory.standardizedFileURL.path] else { return nil }
        return snapshot.summary(for: directory)
    }
}
