// DropboxMountedPaths.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Resolves mounted Dropbox paths used by Share+Link.

import Foundation

// MARK: - DropboxMountedPaths

enum DropboxMountedPaths {
    // MARK: - Root URL

    static func rootURL() -> URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let cloudStorage = home.appendingPathComponent("Library/CloudStorage", isDirectory: true)
        if let children = try? FileManager.default.contentsOfDirectory(
            at: cloudStorage,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ), let dropbox = children.first(where: { $0.lastPathComponent.hasPrefix("Dropbox") && directoryExists($0) }) {
            return dropbox
        }
        let legacy = home.appendingPathComponent("Dropbox", isDirectory: true)
        return directoryExists(legacy) ? legacy : nil
    }

    // MARK: - Public Folder URL

    static func publicFolderURL() -> URL? {
        guard let root = rootURL() else { return nil }
        let publicURL = root.appendingPathComponent("Public", isDirectory: true)
        if directoryExists(publicURL) {
            return publicURL
        }
        do {
            try FileManager.default.createDirectory(at: publicURL, withIntermediateDirectories: true)
            log.info("[CloudLink] created Dropbox public folder at '\(publicURL.path)'")
            return publicURL
        } catch {
            log.warning("[CloudLink] failed to create Dropbox public folder: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Directory Exists

    private static func directoryExists(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }
}
