// JunkScanScope.swift
// MiMiNavigator
// Copyright © 2026 Senatov. All rights reserved.

import Foundation

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

    static func roots() -> [URL] {
        [FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL] + localVolumes()
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
