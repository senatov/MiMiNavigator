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

    // MARK: - Mount Root
    nonisolated private static func appManagedMountRootPath() -> String? {
        guard let supportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        return supportURL
            .appendingPathComponent("MiMiNavigator", isDirectory: true)
            .appendingPathComponent("Mounts", isDirectory: true)
            .standardizedFileURL
            .path
    }
}
