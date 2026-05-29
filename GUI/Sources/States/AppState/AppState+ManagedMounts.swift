//
//  AppState+ManagedMounts.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 18.05.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import Foundation

// MARK: - Managed Mount Detection
extension AppState {

    // MARK: - App Managed Network Mounts
    nonisolated static func isAppManagedNetworkMountPath(_ url: URL) -> Bool {
        guard url.isFileURL else { return false }
        guard let rootPath = appManagedMountRootPath() else { return false }
        let path = url.standardizedFileURL.path
        return path.hasPrefix(rootPath + "/")
    }

    // MARK: - Stale Mount
    nonisolated static func isStaleAppManagedNetworkMountPath(_ url: URL) -> Bool {
        guard isAppManagedNetworkMountPath(url) else { return false }
        guard let mountPointURL = appManagedMountPointURL(for: url) else { return false }
        return !SMBFileProvider.isMounted(at: mountPointURL)
    }

    // MARK: - Mount Point
    nonisolated static func appManagedMountPointURL(for url: URL) -> URL? {
        guard url.isFileURL else { return nil }
        guard let rootPath = appManagedMountRootPath() else { return nil }
        let path = url.standardizedFileURL.path
        guard path.hasPrefix(rootPath + "/") else { return nil }
        let relative = String(path.dropFirst(rootPath.count + 1))
        guard let mountName = relative.split(separator: "/").first else { return nil }
        return URL(fileURLWithPath: rootPath, isDirectory: true)
            .appendingPathComponent(String(mountName), isDirectory: true)
    }

    // MARK: - Mount Point Match
    nonisolated static func isAppManagedNetworkMountPoint(_ url: URL) -> Bool {
        guard let mountPointURL = appManagedMountPointURL(for: url) else { return false }
        return url.standardizedFileURL.path == mountPointURL.standardizedFileURL.path
    }

    // MARK: - Cleanup
    nonisolated static func cleanupStaleAppManagedMounts() async {
        await Task.detached(priority: .utility) {
            guard let mountRootURL = appManagedMountRootURL() else { return }
            let fileManager = FileManager.default
            guard fileManager.fileExists(atPath: mountRootURL.path) else { return }
            let children: [URL]
            do {
                children = try fileManager.contentsOfDirectory(
                    at: mountRootURL,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: [.skipsHiddenFiles]
                )
            } catch {
                log.warning("[ManagedMounts] cannot list mount root path='\(mountRootURL.path)' error=\(error.localizedDescription)")
                return
            }
            for childURL in children {
                cleanStaleMountDirectory(childURL, fileManager: fileManager)
            }
        }.value
    }

    // MARK: - Mount Root
    nonisolated static func appManagedMountRootURL() -> URL? {
        guard let supportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        return supportURL
            .appendingPathComponent("MiMiNavigator", isDirectory: true)
            .appendingPathComponent("Mounts", isDirectory: true)
            .standardizedFileURL
    }

    nonisolated private static func appManagedMountRootPath() -> String? {
        appManagedMountRootURL()?
            .path
    }

    // MARK: - Directory Cleanup
    nonisolated private static func cleanStaleMountDirectory(_ mountPointURL: URL, fileManager: FileManager) {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: mountPointURL.path, isDirectory: &isDirectory), isDirectory.boolValue else { return }
        guard !SMBFileProvider.isMounted(at: mountPointURL) else { return }
        do {
            let entries = try fileManager.contentsOfDirectory(atPath: mountPointURL.path)
            guard entries.isEmpty else {
                log.debug("[ManagedMounts] keep non-empty stale mount path='\(mountPointURL.path)' entries=\(entries.count)")
                return
            }
            try fileManager.removeItem(at: mountPointURL)
            log.info("[ManagedMounts] removed empty stale mount path='\(mountPointURL.path)'")
        } catch {
            log.warning("[ManagedMounts] stale cleanup failed path='\(mountPointURL.path)' error=\(error.localizedDescription)")
        }
    }
}
