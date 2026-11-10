// JunkScanEngine+Artifacts.swift
// MiMiNavigator
// Copyright © 2026 Senatov. All rights reserved.

import AppKit
import Darwin
import FindFilesKit
import Foundation

// MARK: - Application and Process Artifacts
extension JunkScanEngine {
    private static let oldApplicationCacheAge: TimeInterval = 90 * 86_400
    private static let minimumApplicationCacheSize: Int64 = 10 * 1_048_576
    private static let protectedApplicationCacheNameFragments = [
        "account", "icloud", "itunescloud", "appleid", "authentication", "authorization", "identityservice",
        "keychain", "passkit", "screentime", "1password", "agilebits", "bitwarden", "lastpass", "dashlane",
        "keepass", "authy", "yubico", "inputmethod", "credential", "password", "wallet", "signal", "whatsapp"
    ]

    private struct ApplicationCacheMeasurement {
        let size: Int64
        let latestModification: Date
    }

    // MARK: - Stale Third-Party Application Caches
    static func inspectApplicationCaches(access: JunkScanAccess, excludedPaths: [String], into candidates: inout [JunkCandidate]) async throws {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let caches = home.appendingPathComponent("Library/Caches", isDirectory: true)
        guard JunkScanScope.mayInspect(caches.path, from: home, access: access),
              let children = try? FileManager.default.contentsOfDirectory(
                  at: caches,
                  includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
                  options: [.skipsHiddenFiles]
              ) else { return }
        let running = await MainActor.run {
            Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier).map { $0.lowercased() })
        }
        for cache in children {
            try Task.checkCancellation()
            guard isEligibleApplicationCacheRoot(cache, runningBundleIdentifiers: running),
                  !JunkScanScope.isUserExcluded(cache.path, excludedPaths: excludedPaths),
                  JunkScanScope.mayInspect(cache.path, from: home, access: access),
                  let measurement = try await measureApplicationCache(cache, access: access, excludedPaths: excludedPaths),
                  measurement.size >= minimumApplicationCacheSize,
                  Date().timeIntervalSince(measurement.latestModification) > oldApplicationCacheAge else { continue }
            candidates.append(JunkCandidate(
                url: cache,
                kind: .appCache,
                reason: "Closed app cache has been inactive for more than 90 days; review before clearing",
                size: measurement.size,
                group: nil,
                modified: measurement.latestModification
            ))
        }
    }

    // MARK: - Application Cache Path Guard
    static func isApplicationCacheRoot(_ url: URL) -> Bool {
        let caches = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Caches", isDirectory: true).path
        return url.deletingLastPathComponent().path == caches && hasReverseDNSShape(url.lastPathComponent)
            && !url.lastPathComponent.lowercased().hasPrefix("com.apple.")
            && !protectedApplicationCacheNameFragments.contains(where: { url.lastPathComponent.lowercased().contains($0) })
            && !JunkBrowserDataScanner.isKnownBrowserCachePath(url)
    }

    private static func isEligibleApplicationCacheRoot(_ url: URL, runningBundleIdentifiers: Set<String>) -> Bool {
        guard isApplicationCacheRoot(url),
              !runningBundleIdentifiers.contains(where: { $0 == url.lastPathComponent.lowercased() || $0.hasPrefix(url.lastPathComponent.lowercased() + ".") }),
              let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]) else { return false }
        return values.isDirectory == true && values.isSymbolicLink != true
    }

    // MARK: - Restore Cached Application Candidate
    static func isRestorableApplicationCache(_ candidate: JunkCandidate, runningBundleIdentifiers: Set<String>) -> Bool {
        guard candidate.kind == .appCache,
              isEligibleApplicationCacheRoot(candidate.url, runningBundleIdentifiers: runningBundleIdentifiers),
              candidate.size >= minimumApplicationCacheSize,
              let modified = candidate.modified else { return false }
        return Date().timeIntervalSince(modified) > oldApplicationCacheAge
    }

    // MARK: - Measure Application Cache Metadata
    private static func measureApplicationCache(_ root: URL, access: JunkScanAccess, excludedPaths: [String]) async throws -> ApplicationCacheMeasurement? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        var pending = [root]
        var total: Int64 = 0
        var latest = (try? root.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
        var inspected = 0
        while let directory = pending.popLast() {
            try Task.checkCancellation()
            if inspected.isMultiple(of: 128) { try await waitForIdle() }
            inspected += 1
            guard let children = try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            ) else { return nil }
            for child in children {
                try Task.checkCancellation()
                if inspected.isMultiple(of: 256) { try await waitForIdle() }
                inspected += 1
                guard inspected <= 50_000 else { return nil }
                guard !JunkScanScope.isUserExcluded(child.path, excludedPaths: excludedPaths),
                      JunkScanScope.mayInspect(child.path, from: home, access: access),
                      let values = try? child.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey, .contentModificationDateKey]),
                      values.isSymbolicLink != true else { continue }
                latest = max(latest, values.contentModificationDate ?? .distantPast)
                if values.isDirectory == true {
                    pending.append(child)
                } else if values.isRegularFile == true {
                    total += Int64(values.fileSize ?? 0)
                }
            }
        }
        return ApplicationCacheMeasurement(size: total, latestModification: latest)
    }

    // MARK: - Recheck Application Cache Before Trash
    static func stillMatchesApplicationCache(_ candidate: JunkCandidate, access: JunkScanAccess, runningBundleIdentifiers: Set<String>) async -> Bool {
        guard candidate.kind == .appCache,
              isEligibleApplicationCacheRoot(candidate.url, runningBundleIdentifiers: runningBundleIdentifiers),
              let measurement = try? await measureApplicationCache(candidate.url, access: access, excludedPaths: []),
              measurement.size >= minimumApplicationCacheSize,
              measurement.size == candidate.size,
              measurement.latestModification == candidate.modified,
              Date().timeIntervalSince(measurement.latestModification) > oldApplicationCacheAge else { return false }
        return true
    }

    private static func hasReverseDNSShape(_ value: String) -> Bool {
        let components = value.split(separator: ".")
        return components.count >= 2 && components.allSatisfy { !$0.isEmpty && $0.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" } }
    }

    // MARK: - Possible Application Leftovers
    static func inspectApplicationLeftovers(excludedPaths: [String], into candidates: inout [JunkCandidate]) async throws {
        let installed = FindFilesLeftoverSafety.installedApplicationIdentities()
        let running = await MainActor.run {
            Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier).map { $0.lowercased() })
        }
        var newReviews = 0
        // Resolved lazily on the first cache miss: cached verdicts do not need the model,
        // and a model that is still downloading gets a short grace period instead of an instant skip
        var modelReady: Bool?
        for directory in FindFilesLeftoverSafety.searchDirectories {
            if JunkScanScope.isUserExcluded(directory.path, excludedPaths: excludedPaths) { continue }
            guard let children = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isSymbolicLinkKey, .contentModificationDateKey]) else { continue }
            for child in children {
                try Task.checkCancellation()
                if JunkScanScope.isUserExcluded(child.path, excludedPaths: excludedPaths) { continue }
                let name = child.lastPathComponent.lowercased()
                guard !name.hasPrefix("."), name.contains("."),
                      !name.hasPrefix("com.apple."), !name.hasPrefix("group.com.apple."),
                      FindFilesLeftoverSafety.isCandidate(child, installedIdentities: installed),
                      !running.contains(where: { name.contains($0) }),
                      let values = try? child.resourceValues(forKeys: [.isSymbolicLinkKey, .contentModificationDateKey]),
                      values.isSymbolicLink != true,
                      let modified = values.contentModificationDate,
                      Date().timeIntervalSince(modified) > 180 * 86400 else { continue }
                let recommended: Bool
                if let cached = await JunkScanDatabase.shared.aiReview(for: child, modified: modified) {
                    recommended = cached
                } else {
                    guard newReviews < 40 else { continue }
                    if modelReady == nil {
                        // Logs diagnostics, waits while the model is downloading, prewarms when ready
                        modelReady = await JunkAIReviewer.prepare(timeout: .seconds(20))
                    }
                    guard modelReady == true else { continue }
                    try await waitForIdle()
                    guard let review = await JunkAIReviewer.review(child, category: directory.lastPathComponent) else { continue }
                    recommended = review
                    await JunkScanDatabase.shared.saveAIReview(review, for: child, modified: modified)
                    newReviews += 1
                }
                guard recommended else { continue }
                let reason = "Possible leftover from an uninstalled app; on-device AI recommends review"
                candidates.append(JunkCandidate(url: child, kind: .appLeftover, reason: reason, size: 0, group: nil, modified: modified))
            }
        }
    }

    // MARK: - Stale Process Files
    static func inspectStaleProcessArtifacts(excludedPaths: [String], into candidates: inout [JunkCandidate]) async throws {
        let logs = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs", isDirectory: true)
        if JunkScanScope.isUserExcluded(logs.path, excludedPaths: excludedPaths) { return }
        guard let children = try? FileManager.default.contentsOfDirectory(at: logs, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey, .contentModificationDateKey]) else { return }
        for url in children where url.pathExtension.lowercased() == "pid" {
            try Task.checkCancellation()
            if JunkScanScope.isUserExcluded(url.path, excludedPaths: excludedPaths) { continue }
            try await waitForIdle()
            guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey, .contentModificationDateKey]),
                  values.isRegularFile == true, values.isSymbolicLink != true,
                  let modified = values.contentModificationDate,
                  Date().timeIntervalSince(modified) > 30 * 86400,
                  let pid = processID(in: url), !isProcessRunning(pid) else { continue }
            candidates.append(JunkCandidate(url: url, kind: .processArtifact, reason: "PID \(pid) is absent and this process file is older than 30 days", size: Int64(values.fileSize ?? 0), group: nil, modified: modified))
        }
    }

    // MARK: - Process Identity
    static func processID(in url: URL) -> Int32? {
        guard let data = try? Data(contentsOf: url), data.count < 64,
              let text = String(data: data, encoding: .utf8),
              let number = Int32(text.trimmingCharacters(in: .whitespacesAndNewlines)), number > 1 else { return nil }
        return number
    }

    static func isProcessRunning(_ pid: Int32) -> Bool {
        kill(pid, 0) == 0 || errno == EPERM
    }
}
