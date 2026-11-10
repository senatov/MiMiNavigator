// JunkBrowserDataScanner.swift
// MiMiNavigator
// Copyright © 2026 Senatov. All rights reserved.

import AppKit
import Foundation

// MARK: - Non-Default Browser Data Scanner
enum JunkBrowserDataScanner {
    struct RuntimeContext: Sendable {
        let defaultBundleIdentifier: String
        let runningBundleIdentifiers: Set<String>
    }

    private struct BrowserStore {
        let name: String
        let bundleIdentifier: String
        let supportPaths: [String]
        let cachePaths: [String]
    }

    private struct Measurement {
        let size: Int64
        let latestModification: Date
    }

    private static let cacheDirectoryNames: Set<String> = [
        "Cache", "Code Cache", "GPUCache", "ShaderCache", "GrShaderCache", "DawnCache",
        "DawnWebGPUCache", "DawnGraphiteCache", "GraphiteDawnCache", "CachedData", "cache2",
        "CacheStorage", "ScriptCache"
    ]

    private static let privacyDirectoryNames: Set<String> = ["Cookies", "History", "Local Storage", "Session Storage", "IndexedDB", "WebStorage"]
    private static let privacyFileNames: Set<String> = [
        "Cookies", "Cookies-wal", "Cookies-shm", "Cookies-journal", "Cookies.binarycookies",
        "History", "History.db", "History-wal", "History-shm", "History-journal"
    ]

    private static let stores: [BrowserStore] = [
        BrowserStore(name: "Safari", bundleIdentifier: "com.apple.Safari", supportPaths: ["Safari"], cachePaths: ["com.apple.Safari"]),
        BrowserStore(name: "Google Chrome", bundleIdentifier: "com.google.Chrome", supportPaths: ["Application Support/Google/Chrome"], cachePaths: ["Google/Chrome"]),
        BrowserStore(name: "Google Chrome Beta", bundleIdentifier: "com.google.Chrome.beta", supportPaths: ["Application Support/Google/Chrome Beta"], cachePaths: ["Google/Chrome Beta"]),
        BrowserStore(name: "Google Chrome Dev", bundleIdentifier: "com.google.Chrome.dev", supportPaths: ["Application Support/Google/Chrome Dev"], cachePaths: ["Google/Chrome Dev"]),
        BrowserStore(name: "Google Chrome Canary", bundleIdentifier: "com.google.Chrome.canary", supportPaths: ["Application Support/Google/Chrome Canary"], cachePaths: ["Google/Chrome Canary"]),
        BrowserStore(name: "Brave", bundleIdentifier: "com.brave.Browser", supportPaths: ["Application Support/BraveSoftware/Brave-Browser"], cachePaths: ["BraveSoftware/Brave-Browser"]),
        BrowserStore(name: "Microsoft Edge", bundleIdentifier: "com.microsoft.edgemac", supportPaths: ["Application Support/Microsoft Edge"], cachePaths: ["Microsoft Edge"]),
        BrowserStore(name: "Firefox", bundleIdentifier: "org.mozilla.firefox", supportPaths: ["Application Support/Firefox/Profiles"], cachePaths: ["Firefox/Profiles"]),
        BrowserStore(name: "Arc", bundleIdentifier: "company.thebrowser.Browser", supportPaths: ["Application Support/Arc", "Application Support/company.thebrowser.Browser"], cachePaths: ["company.thebrowser.Browser"]),
        BrowserStore(name: "Opera", bundleIdentifier: "com.operasoftware.Opera", supportPaths: ["Application Support/com.operasoftware.Opera"], cachePaths: ["com.operasoftware.Opera"]),
        BrowserStore(name: "Vivaldi", bundleIdentifier: "com.vivaldi.Vivaldi", supportPaths: ["Application Support/Vivaldi"], cachePaths: ["Vivaldi"]),
        BrowserStore(name: "Orion", bundleIdentifier: "com.kagi.kagimacOS", supportPaths: ["Application Support/Orion"], cachePaths: ["com.kagi.kagimacOS"]),
        BrowserStore(name: "DuckDuckGo", bundleIdentifier: "com.duckduckgo.macos.browser", supportPaths: ["Application Support/DuckDuckGo"], cachePaths: ["com.duckduckgo.macos.browser"])
    ]

    // MARK: - Current Browser Context
    @MainActor
    static func runtimeContext() -> RuntimeContext? {
        guard let exampleURL = URL(string: "https://example.com"),
              let browserURL = NSWorkspace.shared.urlForApplication(toOpen: exampleURL),
              let defaultBundleIdentifier = Bundle(url: browserURL)?.bundleIdentifier else { return nil }
        let running = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        return RuntimeContext(defaultBundleIdentifier: defaultBundleIdentifier, runningBundleIdentifiers: running)
    }

    // MARK: - Scan
    static func scan(access: JunkScanAccess, authorizedRoots: [URL], excludedPaths: [String], context: RuntimeContext?) async throws -> [JunkCandidate] {
        guard let context else { return [] }
        let home = FileManager.default.homeDirectoryForCurrentUser
        var results: [JunkCandidate] = []
        var visitedPaths = Set<String>()
        for browser in stores where browser.bundleIdentifier != context.defaultBundleIdentifier
            && !context.runningBundleIdentifiers.contains(browser.bundleIdentifier) {
            let library = home.appendingPathComponent("Library", isDirectory: true)
            for relative in browser.supportPaths {
                let root = library.appendingPathComponent(relative, isDirectory: true)
                results += try await discover(in: root, browser: browser, access: access, authorizedRoots: authorizedRoots, excludedPaths: excludedPaths, cacheOnly: false, visited: &visitedPaths)
            }
            let caches = home.appendingPathComponent("Library/Caches", isDirectory: true)
            for relative in browser.cachePaths {
                let root = caches.appendingPathComponent(relative, isDirectory: true)
                results += try await discover(in: root, browser: browser, access: access, authorizedRoots: authorizedRoots, excludedPaths: excludedPaths, cacheOnly: true, visited: &visitedPaths)
            }
        }
        return results
    }

    // MARK: - Recheck Before Trash
    static func stillMatches(_ candidate: JunkCandidate, access: JunkScanAccess, authorizedRoots: [URL], context: RuntimeContext?) async -> Bool {
        guard let context,
              let browser = stores.first(where: { owns(candidate.url, browser: $0) }),
              browser.bundleIdentifier != context.defaultBundleIdentifier,
              !context.runningBundleIdentifiers.contains(browser.bundleIdentifier),
              let measurement = measure(candidate.url),
              Date().timeIntervalSince(measurement.latestModification) > 3 * 86_400 else { return false }
        let cache = isCacheName(candidate.url.lastPathComponent)
        let permitted = authorizedRoots.contains {
            JunkScanScope.mayInspect(candidate.url.path, from: $0, access: access)
        }
        return candidate.kind == (cache ? .browserCache : .browserPrivacy) && (access == .full || permitted)
    }

    static func isRecognized(_ candidate: JunkCandidate) -> Bool {
        let cache = isCacheName(candidate.url.lastPathComponent)
        guard candidate.kind == (cache ? .browserCache : .browserPrivacy) else { return false }
        return stores.contains { owns(candidate.url, browser: $0) }
    }

    // MARK: - Find Cache and Profile Data
    private static func discover(in root: URL, browser: BrowserStore, access: JunkScanAccess, authorizedRoots: [URL], excludedPaths: [String], cacheOnly: Bool, visited: inout Set<String>) async throws -> [JunkCandidate] {
        guard mayInspect(root.path, access: access, authorizedRoots: authorizedRoots),
              !JunkScanScope.isUserExcluded(root.path, excludedPaths: excludedPaths),
              isRealDirectory(root) else { return [] }
        var output: [JunkCandidate] = []
        var pending: [(URL, Int)] = [(root, 0)]
        var inspected = 0
        while let (directory, depth) = pending.popLast() {
            try Task.checkCancellation()
            if inspected.isMultiple(of: 64) { try await JunkScanEngine.waitForIdle() }
            inspected += 1
            guard depth < 7,
                  !visited.contains(directory.path),
                  let children = try? FileManager.default.contentsOfDirectory(
                      at: directory,
                      includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
                      options: [.skipsHiddenFiles]
                  ) else { continue }
            visited.insert(directory.path)
            for child in children {
                let path = child.standardizedFileURL.path
                guard mayInspect(path, access: access, authorizedRoots: authorizedRoots),
                      !JunkScanScope.isUserExcluded(path, excludedPaths: excludedPaths),
                      let values = try? child.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]),
                      values.isSymbolicLink != true else { continue }
                let isDirectory = values.isDirectory == true
                let name = child.lastPathComponent
                let isCache = isDirectory && isCacheName(name)
                let isPrivacyDirectory = isDirectory && privacyDirectoryNames.contains(name)
                let isPrivacyFile = !isDirectory && privacyFileNames.contains(name)
                if isCache || (!cacheOnly && (isPrivacyDirectory || isPrivacyFile)) {
                    try await JunkScanEngine.waitForIdle()
                    if let measurement = measure(child), Date().timeIntervalSince(measurement.latestModification) > 3 * 86_400 {
                        let kind: JunkCandidate.Kind = isCache ? .browserCache : .browserPrivacy
                        let reason = isCache
                            ? "\(browser.name) cache has been inactive for more than 3 days"
                            : "\(browser.name) cookies, history, or site storage is older than 3 days; clearing it may sign you out"
                        output.append(JunkCandidate(url: child, kind: kind, reason: reason, size: measurement.size, group: nil, modified: measurement.latestModification))
                    }
                    if isDirectory { continue }
                }
                if isDirectory { pending.append((child, depth + 1)) }
            }
        }
        return output
    }

    // MARK: - Measure Metadata Only
    private static func measure(_ url: URL) -> Measurement? {
        let fm = FileManager.default
        guard let attributes = try? fm.attributesOfItem(atPath: url.path),
              let modified = attributes[.modificationDate] as? Date else { return nil }
        if attributes[.type] as? FileAttributeType == .typeRegular {
            return Measurement(size: Int64(attributes[.size] as? Int ?? 0), latestModification: modified)
        }
        guard attributes[.type] as? FileAttributeType == .typeDirectory,
              let enumerator = fm.enumerator(
                  at: url,
                  includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey, .contentModificationDateKey],
                  options: [.skipsHiddenFiles]
              ) else { return nil }
        var total: Int64 = 0
        var latest = modified
        var count = 0
        for case let child as URL in enumerator {
            count += 1
            guard count <= 50_000,
                  let values = try? child.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey, .contentModificationDateKey]),
                  values.isSymbolicLink != true else { return nil }
            if values.isDirectory == true { continue }
            guard values.isRegularFile == true else { continue }
            total += Int64(values.fileSize ?? 0)
            latest = max(latest, values.contentModificationDate ?? .distantPast)
        }
        return Measurement(size: total, latestModification: latest)
    }

    private static func isRealDirectory(_ url: URL) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]) else { return false }
        return values.isDirectory == true && values.isSymbolicLink != true
    }

    private static func owns(_ url: URL, browser: BrowserStore) -> Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let supportRoots = browser.supportPaths.map { home.appendingPathComponent("Library/\($0)").standardizedFileURL.path }
        let cacheRoots = browser.cachePaths.map { home.appendingPathComponent("Library/Caches/\($0)").standardizedFileURL.path }
        return (supportRoots + cacheRoots).contains { isSameOrInside(url.standardizedFileURL.path, root: $0) }
    }

    private static func isCacheName(_ name: String) -> Bool {
        cacheDirectoryNames.contains(name)
    }

    private static func isSameOrInside(_ path: String, root: String) -> Bool {
        path == root || path.hasPrefix(root.hasSuffix("/") ? root : root + "/")
    }

    // MARK: - Permission-Aware Path Check
    private static func mayInspect(_ path: String, access: JunkScanAccess, authorizedRoots: [URL]) -> Bool {
        authorizedRoots.contains { JunkScanScope.mayInspect(path, from: $0, access: access) }
    }
}
