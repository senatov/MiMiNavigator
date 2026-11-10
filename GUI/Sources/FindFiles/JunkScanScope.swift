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
    private static let maximumSymlinkHops = 8
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
        guard access == .limited else { return true }
        let candidate = lexicalPath(path)
        let root = lexicalPath(scanRoot.path)
        let protected = protectedHomeRoots
        let selectedProtectedRoot = protected.first {
            isSameOrInside(root, root: $0) && isSameOrInside(candidate, root: root)
        }
        guard let resolved = resolvingLinks(in: path, fileManager: .default, stopAt: { partial in
            guard protected.contains(where: { isSameOrInside(partial, root: $0) }) else { return false }
            guard selectedProtectedRoot != nil else { return true }
            let leadsToSelectedFolder = isSameOrInside(root, root: partial) || isSameOrInside(partial, root: root)
            return !leadsToSelectedFolder
        }) else { return false }
        if selectedProtectedRoot != nil { return isSameOrInside(lexicalPath(resolved), root: root) }
        return true
    }

    // MARK: - User Exclusions
    static func isUserExcluded(_ path: String, excludedPaths: [String]) -> Bool {
        let candidate = lexicalPath(path)
        return excludedPaths.contains { excluded in
            let root = lexicalPath(excluded)
            return candidate == root || candidate.hasPrefix(root.hasSuffix("/") ? root : root + "/")
        }
    }

    // MARK: - Excluded Child Check
    static func hasExcludedDescendant(_ path: String, excludedPaths: [String]) -> Bool {
        let root = lexicalPath(path)
        return excludedPaths.contains { excluded in
            let candidate = lexicalPath(excluded)
            return candidate.hasPrefix(root.hasSuffix("/") ? root : root + "/")
        }
    }

    // MARK: - Resolve Symlinks Without Opening Targets
    private static func resolvingLinks(in path: String, fileManager: FileManager, stopAt: (String) -> Bool) -> String? {
        var remaining = pathComponents(path)
        var resolved: [String] = []
        var hops = 0
        while !remaining.isEmpty {
            let component = remaining.removeFirst()
            if component == ".." {
                if !resolved.isEmpty { resolved.removeLast() }
                continue
            }
            let next = resolved + [component]
            let nextPath = "/" + next.joined(separator: "/")
            if stopAt(nextPath) { return nil }
            guard let destination = try? fileManager.destinationOfSymbolicLink(atPath: nextPath) else {
                resolved = next
                continue
            }
            hops += 1
            guard hops <= maximumSymlinkHops else { return nil }
            if destination.hasPrefix("/") { resolved = [] }
            remaining = pathComponents(destination) + remaining
        }
        let resolvedPath = "/" + resolved.joined(separator: "/")
        return stopAt(resolvedPath) ? nil : resolvedPath
    }

    private static func lexicalPath(_ path: String) -> String {
        var components: [String] = []
        for component in pathComponents(path) {
            if component == ".." {
                if !components.isEmpty { components.removeLast() }
            } else {
                components.append(component)
            }
        }
        return "/" + components.joined(separator: "/")
    }

    private static func pathComponents(_ path: String) -> [String] {
        path.split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)
            .filter { $0 != "." }
    }

    static func protectedHomeRootsForCurrentUser() -> [String] {
        let home = lexicalPath(FileManager.default.homeDirectoryForCurrentUser.path)
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
        let path = path.lowercased()
        let root = root.lowercased()
        return path == root || path.hasPrefix(root.hasSuffix("/") ? root : root + "/")
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
