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
    private var childRepositoriesByDirectory: [String: [String: GitStatusSnapshot]] = [:]
    private let provider: any GitStatusProviding

    private init(provider: any GitStatusProviding = GitStatusService.shared) {
        self.provider = provider
    }

    func refresh(directory: URL) async {
        let key = directory.standardizedFileURL.path
        let snapshot = await provider.snapshot(for: directory)
        guard !Task.isCancelled else { return }
        var childRepositories: [String: GitStatusSnapshot] = [:]
        let children = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
        for child in children {
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: child.path, isDirectory: &isDirectory), isDirectory.boolValue else { continue }
            guard FileManager.default.fileExists(atPath: child.appendingPathComponent(".git").path) else { continue }
            if let childSnapshot = await provider.snapshot(for: child) {
                childRepositories[child.standardizedFileURL.path] = childSnapshot
            }
            if Task.isCancelled { return }
        }
        snapshotsByDirectory[key] = snapshot
        childRepositoriesByDirectory[key] = childRepositories
    }

    func state(for url: URL, in directory: URL) -> GitFileState? {
        let key = directory.standardizedFileURL.path
        if let child = childRepositoriesByDirectory[key]?[url.standardizedFileURL.path] {
            return child.state(for: url) ?? .clean
        }
        return snapshotsByDirectory[key]?.state(for: url)
    }

    func repositoryRoot(for url: URL, in directory: URL) -> URL? {
        let key = directory.standardizedFileURL.path
        return childRepositoriesByDirectory[key]?[url.standardizedFileURL.path]?.repositoryRoot
            ?? snapshotsByDirectory[key]?.repositoryRoot
    }

    func summary(for directory: URL) -> GitDirectorySummary? {
        guard let snapshot = snapshotsByDirectory[directory.standardizedFileURL.path] else { return nil }
        return snapshot.summary(for: directory)
    }

    func repositoryRoot(for directory: URL) -> URL? {
        snapshotsByDirectory[directory.standardizedFileURL.path]?.repositoryRoot
    }
}
