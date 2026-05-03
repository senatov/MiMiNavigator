//
//  RemoteConnectionManager+PathHelpers.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 04.05.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import Foundation

// MARK: - Remote Path Helpers
extension RemoteConnectionManager {

    func parentPath(for path: String) -> String {
        let parent = (path as NSString).deletingLastPathComponent
        return parent.isEmpty ? "/" : parent
    }

    static func normalizeHost(_ host: String) -> String {
        host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func normalizeRemotePath(_ path: String) -> String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "/" }
        return trimmed
    }
}

// MARK: - SMB Mount Helpers
extension RemoteConnectionManager {

    func expectedSMBMountPointPath(for server: RemoteServer) -> String? {
        guard let decodedShare = Self.firstSMBShareComponent(in: server.remotePath) else { return nil }
        guard !decodedShare.isEmpty else { return nil }
        return "/Volumes/" + decodedShare
    }

    static func firstSMBShareComponent(in remotePath: String) -> String? {
        let trimmed = normalizeRemotePath(remotePath)
        let components = trimmed.split(separator: "/", omittingEmptySubsequences: true)
        guard let share = components.first else { return nil }
        let decodedShare = String(share).removingPercentEncoding ?? String(share)
        return decodedShare.isEmpty ? nil : decodedShare
    }

    static func isSMBMounted(atPath path: String) -> Bool {
        guard FileManager.default.fileExists(atPath: path) else { return false }
        let mountURL = URL(fileURLWithPath: path, isDirectory: true)
        let keys: Set<URLResourceKey> = [.volumeIsLocalKey, .volumeLocalizedFormatDescriptionKey]
        guard let mountedVolumes = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: Array(keys),
            options: []
        ) else {
            return false
        }
        for volumeURL in mountedVolumes where volumeURL.path == mountURL.path {
            guard let values = try? volumeURL.resourceValues(forKeys: keys) else { continue }
            guard values.volumeIsLocal == false else { continue }
            let description = values.volumeLocalizedFormatDescription?.lowercased() ?? ""
            if description.contains("smb") {
                return true
            }
        }
        return false
    }
}
