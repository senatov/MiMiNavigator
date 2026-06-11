// GoogleDriveMountedPaths.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Resolves Google Drive for desktop mounted paths used by sharing UI.

import Foundation

// MARK: - GoogleDriveMountedPaths

enum GoogleDriveMountedPaths {

    // MARK: - My Drive URL

    static func myDriveURL() -> URL? {
        if let url = cloudStorageMyDriveURL() {
            return url
        }
        let fallback = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("My Drive", isDirectory: true)
        return directoryExists(fallback) ? fallback : nil
    }

    // MARK: - Public Folder URL

    static func publicFolderURL() -> URL? {
        guard let root = myDriveURL() else { return nil }
        let publicURL = root.appendingPathComponent(GoogleDriveOAuthConfig.publicFolderName, isDirectory: true)
        if directoryExists(publicURL) {
            return publicURL
        }
        do {
            try FileManager.default.createDirectory(at: publicURL, withIntermediateDirectories: true)
            log.info("[CloudLink] created Google Drive public folder at '\(publicURL.path)'")
            return publicURL
        } catch {
            log.warning("[CloudLink] failed to create Google Drive public folder: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Cloud Storage My Drive URL

    private static func cloudStorageMyDriveURL() -> URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let cloudStorage = home.appendingPathComponent("Library/CloudStorage", isDirectory: true)
        guard let children = try? FileManager.default.contentsOfDirectory(
            at: cloudStorage,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }
        for child in children where child.lastPathComponent.contains("GoogleDrive") {
            let resolved = resolvedURL(child)
            if directoryExists(resolved) {
                return resolved
            }
        }
        return nil
    }

    // MARK: - Resolve URL

    private static func resolvedURL(_ url: URL) -> URL {
        if let aliasResolved = try? URL(resolvingAliasFileAt: url, options: []),
           aliasResolved.path != url.path {
            return aliasResolved
        }
        return url.resolvingSymlinksInPath()
    }

    // MARK: - Directory Exists

    private static func directoryExists(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }
}
