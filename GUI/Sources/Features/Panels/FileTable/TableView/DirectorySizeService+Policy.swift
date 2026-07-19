// DirectorySizeService+Policy.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Automatic directory-size scan policy for expensive filesystem roots.

import Foundation

extension DirectorySizeService {
    nonisolated static func isExpensiveAutomaticRoot(_ url: URL) -> Bool {
        let path = url.resolvingSymlinksInPath().standardizedFileURL.path
        let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path
        let blockedRoots = [
            "/",
            "/Users",
            home,
            home + "/Library",
            home + "/Library/CloudStorage",
            home + "/Library/Mobile Documents",
        ]
        if blockedRoots.contains(path) { return true }
        if path == "/Library" || path.hasPrefix("/Library/") { return true }
        if path == "/System" || path.hasPrefix("/System/") { return true }

        let cloudStorage = home + "/Library/CloudStorage/"
        if path.hasPrefix(cloudStorage) {
            return path.dropFirst(cloudStorage.count).contains("/") == false
        }
        return false
    }
}
