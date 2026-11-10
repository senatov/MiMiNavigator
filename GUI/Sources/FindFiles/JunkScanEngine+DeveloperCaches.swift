// JunkScanEngine+DeveloperCaches.swift
// MiMiNavigator
// Copyright © 2026 Senatov. All rights reserved.

import AppKit
import Foundation

// MARK: - Developer Cache Scan
extension JunkScanEngine {
    private static let developerCacheMinimumSize: Int64 = 100 * 1_048_576
    private static let developerCacheMinimumAge: TimeInterval = 180 * 86_400
    private struct DeveloperCacheMeasurement {
        let size: Int64
        let latestModification: Date
    }

    // MARK: - Scan Known Developer Caches
    static func inspectDeveloperCaches(access: JunkScanAccess, excludedPaths: [String], into candidates: inout [JunkCandidate]) async throws {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let derivedData = home.appendingPathComponent("Library/Developer/Xcode/DerivedData", isDirectory: true)
        let knownRoots = [
            "Library/Caches/Homebrew", "Library/Caches/org.swift.swiftpm", "Library/Caches/Yarn", "Library/Caches/com.apple.dt.Xcode",
            "Library/Developer/CoreSimulator/Caches", ".npm/_cacache", ".npm/_npx",
            ".pnpm-store", "Library/pnpm/store", ".yarn/berry/cache", ".gradle/caches",
            ".cargo/registry", ".cargo/git", ".cache/pre-commit", ".cache/puppeteer",
            ".cache/firebase/emulators", ".cache/go-build", "Library/Caches/go-build",
            ".cache/giget", ".cache/prisma", ".cache/bazel", "Library/Caches/deno"
        ].map { home.appendingPathComponent($0, isDirectory: true) }
        var roots = knownRoots.filter { JunkScanScope.mayInspect($0.path, from: home, access: access) && FileManager.default.fileExists(atPath: $0.path) }
        if JunkScanScope.mayInspect(derivedData.path, from: home, access: access),
           let projects = try? FileManager.default.contentsOfDirectory(at: derivedData, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey], options: [.skipsHiddenFiles]) {
            roots += projects.filter { isRealDeveloperCache($0, home: home) }
        }
        let running = await MainActor.run { Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier).map { $0.lowercased() }) }
        for root in roots {
            try Task.checkCancellation()
            guard isRealDeveloperCache(root, home: home),
                  !(root.path.hasPrefix(derivedData.path + "/") && running.contains("com.apple.dt.xcode")),
                  !JunkScanScope.isUserExcluded(root.path, excludedPaths: excludedPaths),
                  !JunkScanScope.hasExcludedDescendant(root.path, excludedPaths: excludedPaths),
                  JunkScanScope.mayInspect(root.path, from: home, access: access),
                  let measurement = try await measureDeveloperCache(root, home: home, access: access, excludedPaths: excludedPaths),
                  measurement.size >= developerCacheMinimumSize,
                  Date().timeIntervalSince(measurement.latestModification) > developerCacheMinimumAge else { continue }
            candidates.append(JunkCandidate(url: root, kind: .developerCache, reason: "Known developer cache inactive for more than 180 days; check before clearing", size: measurement.size, group: nil, modified: measurement.latestModification))
        }
    }

    // MARK: - Developer Cache Allowlist
    static func isDeveloperCacheRoot(_ url: URL, excludedPaths: [String] = []) -> Bool {
        !JunkScanScope.hasExcludedDescendant(url.path, excludedPaths: excludedPaths)
            && isRealDeveloperCache(url, home: FileManager.default.homeDirectoryForCurrentUser)
    }

    private static func isRealDeveloperCache(_ url: URL, home: URL) -> Bool {
        let path = url.standardizedFileURL.path
        let homePath = home.standardizedFileURL.path
        guard path.hasPrefix(homePath + "/") else { return false }
        let relative = String(path.dropFirst(homePath.count + 1))
        let known = Set([
            "Library/Caches/Homebrew", "Library/Caches/org.swift.swiftpm", "Library/Caches/Yarn", "Library/Caches/com.apple.dt.Xcode",
            "Library/Developer/CoreSimulator/Caches", ".npm/_cacache", ".npm/_npx",
            ".pnpm-store", "Library/pnpm/store", ".yarn/berry/cache", ".gradle/caches",
            ".cargo/registry", ".cargo/git", ".cache/pre-commit", ".cache/puppeteer",
            ".cache/firebase/emulators", ".cache/go-build", "Library/Caches/go-build",
            ".cache/giget", ".cache/prisma", ".cache/bazel", "Library/Caches/deno"
        ])
        let derivedData = home.appendingPathComponent("Library/Developer/Xcode/DerivedData", isDirectory: true).standardizedFileURL.path
        let isDerivedDataProject = url.deletingLastPathComponent().standardizedFileURL.path == derivedData
        guard known.contains(relative) || isDerivedDataProject,
              let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]) else { return false }
        return values.isDirectory == true && values.isSymbolicLink != true
    }

    // MARK: - Recheck Developer Cache Before Trash
    static func stillMatchesDeveloperCache(_ candidate: JunkCandidate, access: JunkScanAccess, excludedPaths: [String]) async -> Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let derivedData = home.appendingPathComponent("Library/Developer/Xcode/DerivedData", isDirectory: true).standardizedFileURL.path
        let xcodeIsRunning = await MainActor.run { NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier?.lowercased() == "com.apple.dt.xcode" } }
        guard candidate.kind == .developerCache, isDeveloperCacheRoot(candidate.url, excludedPaths: excludedPaths),
              !(candidate.url.path.hasPrefix(derivedData + "/") && xcodeIsRunning),
              let measurement = try? await measureDeveloperCache(candidate.url, home: home, access: access, excludedPaths: excludedPaths),
              measurement.size == candidate.size, measurement.size >= developerCacheMinimumSize,
              measurement.latestModification == candidate.modified,
              Date().timeIntervalSince(measurement.latestModification) > developerCacheMinimumAge else { return false }
        return true
    }

    // MARK: - Measure Developer Cache
    private static func measureDeveloperCache(_ root: URL, home: URL, access: JunkScanAccess, excludedPaths: [String]) async throws -> DeveloperCacheMeasurement? {
        var pending = [root]
        var size: Int64 = 0
        var latest = (try? root.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
        var inspected = 0
        while let directory = pending.popLast() {
            try Task.checkCancellation()
            if inspected.isMultiple(of: 128) { try await waitForIdle() }
            guard let children = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey, .contentModificationDateKey], options: [.skipsHiddenFiles]) else { return nil }
            for child in children {
                try Task.checkCancellation()
                if inspected.isMultiple(of: 256) { try await waitForIdle() }
                inspected += 1
                guard inspected <= 50_000 else { return nil }
                guard !JunkScanScope.isUserExcluded(child.path, excludedPaths: excludedPaths),
                      JunkScanScope.mayInspect(child.path, from: home, access: access),
                      let values = try? child.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey, .contentModificationDateKey]),
                      values.isSymbolicLink != true else { return nil }
                latest = max(latest, values.contentModificationDate ?? .distantPast)
                if values.isDirectory == true { pending.append(child) }
                else if values.isRegularFile == true { size += Int64(values.fileSize ?? 0) }
            }
        }
        return DeveloperCacheMeasurement(size: size, latestModification: latest)
    }
}
