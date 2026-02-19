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
    case alreadyMounted(URL)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:           return "Invalid share URL"
        case .mountFailed(let msg): return "Mount failed: \(msg)"
        case .alreadyMounted(let u): return "Already mounted at \(u.path)"
        }
    }
}

// MARK: - SMB/AFP mounter using NSWorkspace
@MainActor
public final class SMBMounter {

    public static let shared = SMBMounter()
    private init() {}

    // MARK: - Mount a host share, returns local /Volumes/ URL
    public func mount(host: NetworkHost) async throws -> URL {
        guard let url = host.smbURL ?? host.afpURL else { throw MountError.invalidURL }

        // Check if already mounted
        if let existing = alreadyMounted(hostName: host.hostName) {
            return existing
        }

        return try await withCheckedThrowingContinuation { continuation in
            NSWorkspace.shared.open(
                [url],
                withAppBundleIdentifier: nil,
                options: [],
                additionalEventParamDescriptor: nil,
                launchIdentifiers: nil
            )
            // NSWorkspace.open for smb:// triggers Finder mount dialog.
            // For direct mount without UI, use NetFS (non-sandboxed only).
            // In sandbox — delegate to Finder, then find mount in /Volumes/
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                guard let self else { return }
                if let mountURL = self.alreadyMounted(hostName: host.hostName) {
                    continuation.resume(returning: mountURL)
                } else {
                    // Finder opened auth dialog — return smb:// as fallback
                    continuation.resume(returning: url)
                }
            }
        }
    }

    // MARK: - Check /Volumes/ for existing mount matching hostName
    public func alreadyMounted(hostName: String) -> URL? {
        let volumesURL = URL(fileURLWithPath: "/Volumes")
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: volumesURL,
            includingPropertiesForKeys: [.volumeNameKey],
            options: .skipsHiddenFiles
        ) else { return nil }

        let baseName = hostName
            .replacingOccurrences(of: ".local", with: "")
            .lowercased()

        return contents.first {
            $0.lastPathComponent.lowercased().contains(baseName)
        }
    }
}
