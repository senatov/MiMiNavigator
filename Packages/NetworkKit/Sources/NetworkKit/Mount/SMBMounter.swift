// SMBMounter.swift
// NetworkKit
//
// Created by Iakov Senatov on 19.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Mounts SMB/AFP shares via NSWorkspace; returns local /Volumes/ URL

import AppKit
import Foundation

// MARK: - Errors
public enum MountError: Error, LocalizedError {
    case invalidURL
    case mountFailed(String)
    case notMounted

    public var errorDescription: String? {
        switch self {
        case .invalidURL:    return "Invalid share URL"
        case .mountFailed(let msg): return "Mount failed: \(msg)"
        case .notMounted:    return "Share was not mounted within timeout"
        }
    }
}

// MARK: - SMB/AFP mounter
@MainActor
public final class SMBMounter {

    public static let shared = SMBMounter()
    private init() {}

    // MARK: - All currently mounted network volumes in /Volumes/
    public func mountedNetworkVolumes() -> [URL] {
        let keys: [URLResourceKey] = [.volumeIsLocalKey, .volumeNameKey]
        guard let volumes = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: keys,
            options: []
        ) else { return [] }

        return volumes.filter { url in
            guard let vals = try? url.resourceValues(forKeys: Set(keys)),
                  let isLocal = vals.volumeIsLocal else { return false }
            // Network volumes are non-local, exclude Macintosh HD variants
            return !isLocal
        }
    }

    // MARK: - Open smb:// URL — triggers macOS mount dialog in Finder
    public func openForMount(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    // MARK: - Poll /Volumes/ for new network mounts, returning newly appeared ones
    // Snapshots before/after and returns diff
    public func pollForNewMount(
        snapshot: [URL],
        timeout: TimeInterval = 30
    ) async -> URL? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            try? await Task.sleep(for: .seconds(1))
            let current = mountedNetworkVolumes()
            let newVolumes = current.filter { cur in
                !snapshot.contains { $0.path == cur.path }
            }
            if let first = newVolumes.first {
                return first
            }
        }
        return nil
    }
}
