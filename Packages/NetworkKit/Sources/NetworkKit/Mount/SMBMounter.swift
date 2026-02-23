// SMBMounter.swift
// NetworkKit
//
// Created by Iakov Senatov on 19.02.2026.
// Refactored: 22.02.2026 — mountShare via /sbin/mount_smbfs (no Finder popup)
// Refactored: 23.02.2026 — no NSWorkspace fallback; already-mounted check before mount_smbfs
// Refactored: 23.02.2026 — os.Logger (log) replaces all print() calls
// Copyright (c) 2026 Senatov. All rights reserved.

import AppKit
import Foundation
import LogKit

// MARK: - Errors
public enum MountError: Error, LocalizedError {
    case invalidURL
    case mountFailed(String)
    case notMounted
    public var errorDescription: String? {
        switch self {
        case .invalidURL:           return "Invalid share URL"
        case .mountFailed(let msg): return "Mount failed: \(msg)"
        case .notMounted:           return "Share was not mounted within timeout"
        }
    }
}

// MARK: - SMB/AFP mounter
@MainActor
public final class SMBMounter {
    public static let shared = SMBMounter()
    private init() {}

    // MARK: - All currently mounted network volumes
    public func mountedNetworkVolumes() -> [URL] {
        let keys: [URLResourceKey] = [.volumeIsLocalKey, .volumeNameKey]
        guard let volumes = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: keys, options: []
        ) else { return [] }
        return volumes.filter { url in
            guard let vals = try? url.resourceValues(forKeys: Set(keys)),
                  let isLocal = vals.volumeIsLocal else { return false }
            return !isLocal
        }
    }

    // MARK: - Mount share silently via /sbin/mount_smbfs
    // -N = no password prompt. Returns nil (not Finder) when auth is required.
    public func mountShare(_ shareURL: URL) async -> URL? {
        guard shareURL.scheme == "smb" || shareURL.scheme == "afp" else {
            NSWorkspace.shared.open(shareURL)
            return nil
        }
        let before    = mountedNetworkVolumes()
        let host      = shareURL.host ?? "network"
        let shareName = shareURL.lastPathComponent.isEmpty ? "share" : shareURL.lastPathComponent

        // Check if already mounted — avoid redundant mount_smbfs call
        let alreadyMounted = [
            URL(fileURLWithPath: "/Volumes/\(shareName)"),
            URL(fileURLWithPath: "/Volumes/\(host)-\(shareName)"),
            URL(fileURLWithPath: "/Volumes/\(shareName.removingPercentEncoding ?? shareName)"),
        ]
        for candidate in alreadyMounted where FileManager.default.fileExists(atPath: candidate.path) {
            log.debug("[SMBMounter] already mounted at \(candidate.path)")
            return candidate
        }

        let mountName  = "\(host)-\(shareName)".replacingOccurrences(of: " ", with: "-")
        let mountPoint = "/Volumes/\(mountName)"
        try? FileManager.default.createDirectory(atPath: mountPoint, withIntermediateDirectories: true)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/sbin/mount_smbfs")
        process.arguments = ["-N", shareURL.absoluteString, mountPoint]
        let errPipe = Pipe()
        process.standardError = errPipe
        do { try process.run() } catch {
            log.error("[SMBMounter] launch failed: \(error.localizedDescription)")
            try? FileManager.default.removeItem(atPath: mountPoint)
            return await fallbackMount(shareURL: shareURL, before: before)
        }
        let deadline = Date().addingTimeInterval(10)
        while process.isRunning && Date() < deadline {
            try? await Task.sleep(for: .milliseconds(200))
        }
        if process.isRunning { process.terminate() }
        if process.terminationStatus == 0 {
            log.info("[SMBMounter] mounted \(shareURL.absoluteString) -> \(mountPoint)")
            return URL(fileURLWithPath: mountPoint)
        }
        let errStr = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        log.warning("[SMBMounter] exit=\(process.terminationStatus): \(errStr.trimmingCharacters(in: .whitespacesAndNewlines))")
        try? FileManager.default.removeItem(atPath: mountPoint)
        return await fallbackMount(shareURL: shareURL, before: before)
    }

    // MARK: - Fallback: check if share appeared or was already mounted
    // NSWorkspace.open(smb://) intentionally removed — it opens Finder.
    // Returns nil → caller shows Sign In instead.
    private func fallbackMount(shareURL: URL, before: [URL]) async -> URL? {
        try? await Task.sleep(for: .milliseconds(800))
        let current = mountedNetworkVolumes()
        if let appeared = current.first(where: { cur in !before.contains { $0.path == cur.path } }) {
            log.info("[SMBMounter] auto-mounted: \(appeared.path)")
            return appeared
        }
        let shareName = shareURL.lastPathComponent
        let host      = shareURL.host ?? ""
        let candidates = [
            URL(fileURLWithPath: "/Volumes/\(shareName)"),
            URL(fileURLWithPath: "/Volumes/\(host)-\(shareName)"),
        ]
        for candidate in candidates where FileManager.default.fileExists(atPath: candidate.path) {
            log.info("[SMBMounter] found existing mount: \(candidate.path)")
            return candidate
        }
        log.info("[SMBMounter] silent mount failed for \(shareURL.absoluteString) — auth required")
        return nil
    }

    // MARK: - Legacy
    public func openForMount(_ url: URL) { NSWorkspace.shared.open(url) }

    // MARK: - Poll /Volumes/ for new network mount
    public func pollForNewMount(snapshot: [URL], timeout: TimeInterval = 30) async -> URL? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            try? await Task.sleep(for: .seconds(1))
            let current = mountedNetworkVolumes()
            if let first = current.first(where: { cur in !snapshot.contains { $0.path == cur.path } }) {
                return first
            }
        }
        return nil
    }
}
