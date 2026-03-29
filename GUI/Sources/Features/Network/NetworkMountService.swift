// NetworkMountService.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 19.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Opens network hosts in Finder and detects already-mounted volumes.

import AppKit
import Foundation

// MARK: - Finder-based network mounting
@MainActor
final class NetworkMountService {

    static let shared = NetworkMountService()
    private init() {}

    // MARK: - Finder
    private var finderBundleIdentifier: String {
        "com.apple.finder"
    }

    private var volumesDirectoryURL: URL {
        URL(fileURLWithPath: "/Volumes")
    }

    private struct MountedVolumeCandidate {
        let url: URL
        let score: Int
    }

    private struct MatchToken {
        let value: String
        let scoreBoost: Int
    }

    private func normalizedMatchTokens(for host: NetworkHost) -> [MatchToken] {
        let rawTokens: [(String, Int)] = [
            (host.hostName, 20),
            (host.effectiveHostName, 15),
            (host.hostIP, 15),
            (host.hostDisplayName, 10),
            (host.name, 5),
        ]

        let filteredTokens = rawTokens
            .map { value, scoreBoost in
                MatchToken(
                    value: value.trimmingCharacters(in: .whitespacesAndNewlines),
                    scoreBoost: scoreBoost
                )
            }
            .filter { !$0.value.isEmpty && $0.value != "(nil)" }

        var uniqueTokens: [MatchToken] = []
        for token in filteredTokens {
            if !uniqueTokens.contains(where: { $0.value.caseInsensitiveCompare(token.value) == .orderedSame }) {
                uniqueTokens.append(token)
            }
        }

        return uniqueTokens
    }

    private func normalizedVolumeName(_ volume: URL) -> String {
        volume.lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func shouldIgnoreMountedVolume(_ volume: URL) -> Bool {
        let volumeName = normalizedVolumeName(volume)
        return volumeName.isEmpty || volumeName == ".DS_Store"
    }

    private func tieBreakVolumeName(_ volume: URL) -> String {
        normalizedVolumeName(volume).lowercased()
    }

    private func matchScore(volumeName: String, token: MatchToken) -> Int {
        if volumeName.caseInsensitiveCompare(token.value) == .orderedSame {
            return 100 + token.scoreBoost
        }

        let normalizedVolumeName = volumeName.lowercased()
        let normalizedToken = token.value.lowercased()

        if normalizedVolumeName.hasPrefix(normalizedToken) {
            return 75 + token.scoreBoost
        }
        if normalizedVolumeName.contains(normalizedToken) {
            return 50 + token.scoreBoost
        }
        return 0
    }

    private func candidateForMountedVolume(_ volume: URL, host: NetworkHost) -> MountedVolumeCandidate? {
        guard !shouldIgnoreMountedVolume(volume) else { return nil }

        let volumeName = normalizedVolumeName(volume)
        let matchTokens = normalizedMatchTokens(for: host)

        let bestScore = matchTokens
            .map { matchScore(volumeName: volumeName, token: $0) }
            .max() ?? 0

        guard bestScore > 0 else { return nil }
        return MountedVolumeCandidate(url: volume, score: bestScore)
    }

    private func activateFinderIfRunning() {
        NSWorkspace.shared.runningApplications
            .first { $0.bundleIdentifier == finderBundleIdentifier }?
            .activate()
    }

    private func mountedVolumeNames() -> [URL] {
        let fileManager = FileManager.default
        guard let volumes = try? fileManager.contentsOfDirectory(
            at: volumesDirectoryURL,
            includingPropertiesForKeys: nil
        ) else {
            return []
        }
        return volumes
    }

    private func bestMountedVolumeMatch(for host: NetworkHost) -> URL? {
        let candidates = mountedVolumeNames().compactMap { volume in
            candidateForMountedVolume(volume, host: host)
        }

        let bestMatch = candidates.max { lhs, rhs in
            if lhs.score == rhs.score {
                return tieBreakVolumeName(lhs.url) > tieBreakVolumeName(rhs.url)
            }
            return lhs.score < rhs.score
        }

        if let bestMatch {
            log.debug("[NetworkMount] mounted match host=\(host.name)")
            log.debug("[NetworkMount] matched volume=\(bestMatch.url.lastPathComponent)")
            log.debug("[NetworkMount] match score=\(bestMatch.score)")
        }

        return bestMatch?.url
    }

    // MARK: - Open host in Finder (always works, handles auth UI natively)
    func openInFinder(_ host: NetworkHost) {
        guard let url = host.mountURL else {
            log.warning("[NetworkMount] no URL for host \(host.name)")
            return
        }
        log.info("[NetworkMount] openInFinder: \(url)")
        let didOpen = NSWorkspace.shared.open(url)
        if didOpen {
            activateFinderIfRunning()
        } else {
            log.warning("[NetworkMount] Finder open failed for \(url)")
        }
    }

    // MARK: - Try to find already-mounted volume for this host
    func mountedURL(for host: NetworkHost) -> URL? {
        bestMountedVolumeMatch(for: host)
    }
}
