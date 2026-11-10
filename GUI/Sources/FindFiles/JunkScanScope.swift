// JunkScanScope.swift
// MiMiNavigator
// Copyright © 2026 Senatov. All rights reserved.

import Foundation

// MARK: - Junk Scan Access Level
enum JunkScanAccess: Sendable, Equatable {
    case limited
    case full
}

// MARK: - Automatic Cleanup Scope
enum JunkScanScope {
    private static let timeMachineMounts: Set<String> = {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tmutil")
        process.arguments = ["destinationinfo", "-X"]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()
        guard (try? process.run()) != nil else { return [] }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0,
              let propertyList = try? PropertyListSerialization.propertyList(from: data, format: nil),
              let dictionary = propertyList as? [String: Any],
              let destinations = dictionary["Destinations"] as? [[String: Any]] else { return [] }
        return Set(destinations.compactMap { $0["MountPoint"] as? String })
    }()

    // MARK: - Scan Access
    static func scanAccess() -> JunkScanAccess {
        hasFullDiskAccess() ? .full : .limited
    }

    static func hasFullDiskAccess() -> Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let probes = [
            home.appendingPathComponent("Library/Safari", isDirectory: true),
            home.appendingPathComponent("Library/Containers", isDirectory: true),
            home.appendingPathComponent("Library/Application Support", isDirectory: true)
        ]
        return probes.allSatisfy(canList)
    }

    static func canList(_ url: URL) -> Bool {
        var failed = false
        let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [],
            options: [.skipsSubdirectoryDescendants]
        ) { _, _ in
            failed = true
            return false
        }
        guard let enumerator else { return false }
        _ = enumerator.nextObject()
        return !failed
    }

    static func roots(access: JunkScanAccess, authorizedFolders: [URL]) -> [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL
        let baseRoots = [home] + (access == .full ? localVolumes() : [])
        let extraRoots = authorizedFolders.filter { folder in
            let path = folder.standardizedFileURL.path
            guard !path.isEmpty, !path.hasSuffix("/") || path == "/" else { return false }
            guard !path.hasPrefix(home.path + "/Library/CloudStorage/") else { return false }
            guard !timeMachineMounts.contains(where: { isSameOrInside(path, root: $0) }) else { return false }
            let isProtectedHomeFolder = protectedHomeRoots.contains { isSameOrInside(path, root: $0) }
            let isLibraryFolder = isSameOrInside(path, root: home.path + "/Library")
            let isOutsideBaseRoots = !baseRoots.contains { isSameOrInside(path, root: $0.path) }
            return isProtectedHomeFolder || isLibraryFolder || isOutsideBaseRoots
        }
        var seen = Set<String>()
        return (baseRoots + extraRoots).filter { seen.insert($0.standardizedFileURL.path).inserted }
    }

    static func mayInspect(_ path: String, from scanRoot: URL, access: JunkScanAccess) -> Bool {
        guard access == .full else {
            let standardized = URL(fileURLWithPath: path).standardizedFileURL.path
            guard let protectedRoot = protectedHomeRoots.first(where: { isSameOrInside(standardized, root: $0) }) else { return true }
            return isSameOrInside(scanRoot.standardizedFileURL.path, root: protectedRoot)
                && isSameOrInside(standardized, root: scanRoot.standardizedFileURL.path)
        }
        return true
    }

    // MARK: - User Exclusions
    static func isUserExcluded(_ path: String, excludedPaths: [String]) -> Bool {
        let candidate = URL(fileURLWithPath: path).standardizedFileURL.path
        return excludedPaths.contains { excluded in
            let root = URL(fileURLWithPath: excluded).standardizedFileURL.path
            return candidate == root || candidate.hasPrefix(root.hasSuffix("/") ? root : root + "/")
        }
    }

    static func protectedHomeRootsForCurrentUser() -> [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path
        return protectedHomeRelativePaths.map { "\(home)/\($0)" }
    }

    private static let protectedHomeRelativePaths = [
        "Desktop", "Documents", "Downloads", "Library/Containers", "Library/Group Containers",
        "Library/Mobile Documents", "Library/CloudStorage", "Library/Safari", "Library/Mail",
        "Library/Messages", "Library/Caches/com.apple.Music", "Library/Caches/com.apple.iTunes",
        "Library/Caches/com.apple.TV", "Library/Caches/com.apple.podcasts", "Library/Caches/com.apple.watchlistd",
        "Library/Caches/com.apple.AMPLibraryAgent", "Library/Caches/com.apple.AMPArtworkAgent",
        "Library/Caches/com.apple.AMPDevicesAgent"
    ]

    private static var protectedHomeRoots: [String] { protectedHomeRootsForCurrentUser() }

    private static func isSameOrInside(_ path: String, root: String) -> Bool {
        path == root || path.hasPrefix(root.hasSuffix("/") ? root : root + "/")
    }

    // MARK: - Writable Local Volumes
    static func localVolumes() -> [URL] {
        let keys: [URLResourceKey] = [.volumeIsLocalKey, .volumeIsReadOnlyKey, .volumeIsBrowsableKey]
        return (FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) ?? [])
            .filter { url in
                let path = url.standardizedFileURL.resolvingSymlinksInPath().path
                guard path.hasPrefix("/Volumes/"), !path.contains("/Library/CloudStorage/"),
                      !timeMachineMounts.contains(path),
                      !url.lastPathComponent.localizedCaseInsensitiveContains("backup"),
                      !FileManager.default.fileExists(atPath: url.appendingPathComponent("Backups.backupdb").path) else { return false }
                guard let values = try? url.resourceValues(forKeys: Set(keys)) else { return false }
                return values.volumeIsLocal == true && values.volumeIsReadOnly == false && values.volumeIsBrowsable == true
            }
            .map { $0.standardizedFileURL.resolvingSymlinksInPath() }
    }
}
