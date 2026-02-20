// NetworkMountService.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 19.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Mounts SMB/AFP shares via NSWorkspace; falls back to Finder for auth

import AppKit
import Foundation

// MARK: - Mounts network shares into /Volumes/
@MainActor
final class NetworkMountService {

    static let shared = NetworkMountService()
    private init() {}

    // MARK: - Open host in Finder (always works, handles auth UI natively)
    func openInFinder(_ host: NetworkHost) {
        guard let url = host.mountURL else {
            log.warning("[NetworkMount] no URL for host \(host.name)")
            return
        }
        log.info("[NetworkMount] openInFinder: \(url)")
        NSWorkspace.shared.open(url)
        // Bring Finder to front
        NSWorkspace.shared.runningApplications
            .first { $0.bundleIdentifier == "com.apple.finder" }?
            .activate()
    }

    // MARK: - Try to find already-mounted volume for this host
    func mountedURL(for host: NetworkHost) -> URL? {
        let fm = FileManager.default
        guard let vols = try? fm.contentsOfDirectory(
            at: URL(fileURLWithPath: "/Volumes"),
            includingPropertiesForKeys: nil
        ) else { return nil }

        return vols.first { vol in
            vol.lastPathComponent.localizedCaseInsensitiveContains(host.name) ||
            vol.lastPathComponent.localizedCaseInsensitiveContains(host.hostName)
        }
    }
}
