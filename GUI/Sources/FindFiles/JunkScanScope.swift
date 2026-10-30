// JunkScanScope.swift
// MiMiNavigator
// Copyright © 2026 Senatov. All rights reserved.

import Foundation

// MARK: - Automatic Cleanup Scope
enum JunkScanScope {
    static func roots() -> [URL] {
        [FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL] + localVolumes()
    }

    // MARK: - Writable Local Volumes
    static func localVolumes() -> [URL] {
        let keys: [URLResourceKey] = [.volumeIsLocalKey, .volumeIsReadOnlyKey, .volumeIsBrowsableKey]
        return (FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) ?? [])
            .filter { url in
                let path = url.standardizedFileURL.resolvingSymlinksInPath().path
                guard path.hasPrefix("/Volumes/"), !path.contains("/Library/CloudStorage/") else { return false }
                guard let values = try? url.resourceValues(forKeys: Set(keys)) else { return false }
                return values.volumeIsLocal == true && values.volumeIsReadOnly == false && values.volumeIsBrowsable == true
            }
            .map { $0.standardizedFileURL.resolvingSymlinksInPath() }
    }
}
