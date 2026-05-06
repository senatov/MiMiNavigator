// OpenWithService.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 04.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Service for "Open With" functionality - fetches available applications

import AppKit
import FileModelKit
import Foundation

// MARK: - Open With Service
/// Fetches applications capable of opening specific file types
@MainActor
final class OpenWithService {

    static let shared = OpenWithService()
    private let workspace = NSWorkspace.shared
    private let fileManager = FileManager.default
    private let notificationCenter = NotificationCenter.default
    private let remoteConnectionManager = RemoteConnectionManager.shared

    private enum Constants {
        static let noExtensionKey = "__noext__"
        static let maxLRUCount = 5
        static let applicationDirectory = "/Applications"
        static let appIconSize = NSSize(width: 16, height: 16)
        static let logPrefix = "[OpenWithService]"
        static let cacheHitMaxAgeMs = 60_000
    }

    // MARK: - Apps cache
    private struct MenuCacheEntry {
        let apps: [AppInfo]
        let createdAt: Date

        var ageMs: Int {
            Int(Date().timeIntervalSince(createdAt) * 1000)
        }

        var isFresh: Bool {
            ageMs <= Constants.cacheHitMaxAgeMs
        }
    }

    private struct CachedAppDescriptor {
        let bundleIdentifier: String
        let name: String
        let icon: NSImage
        let url: URL
    }

    private static var menuCache: [String: MenuCacheEntry] = [:]
    private static var appDescriptorCache: [String: CachedAppDescriptor] = [:]
    private static var requestSequence: Int = 0

    private func logDebug(_ message: String) {
        log.debug("\(Constants.logPrefix) \(message)")
    }

    private func logInfo(_ message: String) {
        log.info("\(Constants.logPrefix) \(message)")
    }

    private func logError(_ message: String) {
        log.error("\(Constants.logPrefix) \(message)")
    }

    private init() {
        logDebug("initialized")
    }

    private var lruDefaultsKey: String { "openWithLRU" }
    private var lruAppURLsKey: String { "openWithAppURLs" }
    private var userAssociationsKey: String { "openWithUserAssociations" }

    private func nextRequestID() -> Int {
        Self.requestSequence += 1
        return Self.requestSequence
    }

    private func defaultApplicationURL(for fileURL: URL) -> URL? {
        let appURL = workspace.urlForApplication(toOpen: fileURL)
        logDebug("defaultApplicationURL file='\(fileURL.lastPathComponent)' app='\(appURL?.lastPathComponent ?? "none")'")
        return appURL
    }

    private func cachedApps(for cacheKey: String, requestID: Int) -> [AppInfo]? {
        guard let cached = Self.menuCache[cacheKey] else {
            return nil
        }

        if !cached.isFresh {
            Self.menuCache.removeValue(forKey: cacheKey)
            logDebug("cache expired #\(requestID) ageMs=\(cached.ageMs) count=\(cached.apps.count)")
            return nil
        }

        logDebug("cache hit #\(requestID) count=\(cached.apps.count) ageMs=\(cached.ageMs)")
        return cached.apps
    }

    private func storeMenuCache(_ apps: [AppInfo], for cacheKey: String) {
        Self.menuCache[cacheKey] = MenuCacheEntry(apps: apps, createdAt: Date())
        logDebug("storeMenuCache count=\(apps.count)")
    }

    private func isRemoteFileURL(_ fileURL: URL) -> Bool {
        let isRemote = fileURL.scheme == "sftp" || fileURL.scheme == "ftp"
        if isRemote {
            logDebug("isRemoteFileURL=true scheme='\(fileURL.scheme ?? "nil")' path='\(fileURL.path)'")
        }
        return isRemote
    }

    // MARK: - Key helpers

    private func normalizedExtensionKey(for ext: String) -> String {
        let normalized = ext.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized.isEmpty ? Constants.noExtensionKey : normalized
    }

    func normalizedCacheExtension(for ext: String) -> String {
        normalizedExtensionKey(for: ext)
    }

    private func savedAppURLs() -> [String: String] {
        guard let urls = MiMiDefaults.shared.dictionary(forKey: lruAppURLsKey) as? [String: String] else {
            return [:]
        }

        return urls
    }

    private func makeMenuCacheKey(ext: String, defaultApp: URL?, recentBundles: [String]) -> String {
        let defaultBundleIdentifier = defaultApp
            .flatMap { Bundle(url: $0)?.bundleIdentifier }
            ?? "__nodefault__"
        let lruSignature = recentBundles.joined(separator: "|")

        return "\(ext)#\(defaultBundleIdentifier)#\(lruSignature)"
    }

    private func userAssociatedBundle(for ext: String) -> String? {
        let key = normalizedExtensionKey(for: ext)
        let defaults = MiMiDefaults.shared.dictionary(forKey: userAssociationsKey) as? [String: String]
        return defaults?[key]
    }

    private func storeUserAssociation(bundleID: String, ext: String, appURL: URL) {
        let key = normalizedExtensionKey(for: ext)
        var defaults = MiMiDefaults.shared.dictionary(forKey: userAssociationsKey) as? [String: String] ?? [:]
        defaults[key] = bundleID
        MiMiDefaults.shared.set(defaults, forKey: userAssociationsKey)
        storeAppURLIfNeeded(appURL, for: bundleID)
        invalidateCache(for: ext)
        logInfo("user association updated key='\(key)' bundle='\(bundleID)'")
    }

    private func cachePrefix(for ext: String) -> String {
        "\(ext)#"
    }

    // MARK: - LRU helpers

    /// Returns bundle IDs of recently-used apps for a given file extension, newest first
    private func lruBundles(for ext: String) -> [String] {
        let key = normalizedExtensionKey(for: ext)
        let defaults = MiMiDefaults.shared.dictionary(forKey: lruDefaultsKey) as? [String: [String]]
        let bundles = defaults?[key] ?? []

        logDebug("lruBundles key='\(key)' count=\(bundles.count)")
        return bundles
    }

    /// Records that `bundleID` was used to open a file with `ext`
    private func recordLRU(bundleID: String, ext: String, appURL: URL? = nil) {
        let key = normalizedExtensionKey(for: ext)
        var defaults = MiMiDefaults.shared.dictionary(forKey: lruDefaultsKey) as? [String: [String]] ?? [:]
        var bundles = defaults[key] ?? []

        bundles.removeAll { $0 == bundleID }
        bundles.insert(bundleID, at: 0)

        if bundles.count > Constants.maxLRUCount {
            bundles = Array(bundles.prefix(Constants.maxLRUCount))
        }

        defaults[key] = bundles
        MiMiDefaults.shared.set(defaults, forKey: lruDefaultsKey)

        storeAppURLIfNeeded(appURL, for: bundleID)
        invalidateCache(for: ext)

        logInfo("LRU updated key='\(key)' top='\(bundleID)'")
        logDebug("LRU bundles=\(bundles)")
    }

    private func storeAppURLIfNeeded(_ appURL: URL?, for bundleID: String) {
        guard let appURL else {
            return
        }

        var urls = savedAppURLs()
        urls[bundleID] = appURL.path
        MiMiDefaults.shared.set(urls, forKey: lruAppURLsKey)

        logDebug("stored appURL bundle='\(bundleID)'")
        logDebug("stored path='\(appURL.path)'")
    }

    // MARK: - Cache Invalidation
    /// Notification posted when Open With LRU order changes; userInfo["ext"] contains the extension
    static let cacheInvalidatedNotification = Notification.Name("OpenWithService.cacheInvalidated")
    /// Removes cached app list for the given extension so it is rebuilt with fresh LRU order
    func invalidateCache(for ext: String) {
        let normalizedExt = normalizedExtensionKey(for: ext)
        let prefix = cachePrefix(for: normalizedExt)
        let keysToRemove = Self.menuCache.keys.filter { $0.hasPrefix(prefix) }

        for key in keysToRemove {
            Self.menuCache.removeValue(forKey: key)
        }

        notificationCenter.post(
            name: Self.cacheInvalidatedNotification,
            object: nil,
            userInfo: ["ext": normalizedExt]
        )

        logDebug("invalidateCache ext='\(normalizedExt)' removed=\(keysToRemove.count)")
    }

    // MARK: - Applications Lookup

    /// Returns list of applications that can open the given file
    func getApplications(for fileURL: URL) -> [AppInfo] {
        let startedAt = CFAbsoluteTimeGetCurrent()
        let requestID = nextRequestID()
        let ext = fileURL.pathExtension
        let normalizedExt = normalizedExtensionKey(for: ext)
        let defaultApp = defaultApplicationURL(for: fileURL)
        let recentBundles = lruBundles(for: ext)
        let cacheKey = makeMenuCacheKey(ext: normalizedExt, defaultApp: defaultApp, recentBundles: recentBundles)

        logDebug("getApplications #\(requestID) file='\(fileURL.lastPathComponent)'")
        logDebug("getApplications ext='\(normalizedExt)' default='\(defaultApp?.lastPathComponent ?? "none")'")

        if let cachedApps = cachedApps(for: cacheKey, requestID: requestID) {
            return cachedApps
        }

        var apps: [AppInfo] = []
        var seenBundles = Set<String>()
        var seenAppPaths = Set<String>()
        let launchServiceAppURLs = applicationURLs(for: fileURL)
        let userAssociatedBundle = userAssociatedBundle(for: ext)

        logDebug("LS apps count=\(launchServiceAppURLs.count)")

        for appURL in launchServiceAppURLs {
            appendAppIfNeeded(
                from: appURL,
                defaultApp: defaultApp,
                seenBundles: &seenBundles,
                seenAppPaths: &seenAppPaths,
                apps: &apps
            )
        }

        appendMissingRecentApps(
            recentBundles: recentBundles,
            preferredBundle: userAssociatedBundle,
            defaultApp: defaultApp,
            seenBundles: &seenBundles,
            seenAppPaths: &seenAppPaths,
            apps: &apps
        )

        sortApplications(&apps, recentBundles: recentBundles, preferredBundle: userAssociatedBundle)

        let orderedBundles = apps.map(\.bundleIdentifier)
        let elapsedMs = Int((CFAbsoluteTimeGetCurrent() - startedAt) * 1000)

        logInfo("built apps #\(requestID) count=\(apps.count) elapsed=\(elapsedMs)ms")
        logInfo("ext='\(normalizedExt)' default='\(defaultApp?.lastPathComponent ?? "none")'")
        logDebug("ordered=\(orderedBundles)")

        storeMenuCache(apps, for: cacheKey)
        return apps
    }

    private func appendMissingRecentApps(
        recentBundles: [String],
        preferredBundle: String?,
        defaultApp: URL?,
        seenBundles: inout Set<String>,
        seenAppPaths: inout Set<String>,
        apps: inout [AppInfo]
    ) {
        let knownBundles = Set(apps.map(\.bundleIdentifier))
        let savedURLs = savedAppURLs()
        let bundlesToRestore = ([preferredBundle].compactMap { $0 } + recentBundles).filter { !knownBundles.contains($0) }

        for bundleID in bundlesToRestore {
            guard let path = savedURLs[bundleID], fileManager.fileExists(atPath: path) else {
                logDebug("missing saved LRU app bundle='\(bundleID)'")
                continue
            }

            let appURL = URL(fileURLWithPath: path)
            appendAppIfNeeded(
                from: appURL,
                defaultApp: defaultApp,
                seenBundles: &seenBundles,
                seenAppPaths: &seenAppPaths,
                apps: &apps
            )

            if let restoredApp = apps.last, restoredApp.bundleIdentifier == bundleID {
                logDebug("restored LRU app='\(restoredApp.name)'")
            }
        }
    }

    private func sortApplications(_ apps: inout [AppInfo], recentBundles: [String], preferredBundle: String?) {
        apps.sort { lhs, rhs in
            if lhs.bundleIdentifier == preferredBundle && rhs.bundleIdentifier != preferredBundle {
                return true
            }
            if rhs.bundleIdentifier == preferredBundle && lhs.bundleIdentifier != preferredBundle {
                return false
            }
            let lhsLRU = recentBundles.firstIndex(of: lhs.bundleIdentifier) ?? Int.max
            let rhsLRU = recentBundles.firstIndex(of: rhs.bundleIdentifier) ?? Int.max

            if lhsLRU != rhsLRU {
                return lhsLRU < rhsLRU
            }

            if lhs.isDefault != rhs.isDefault {
                return lhs.isDefault
            }

            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private func applicationURLs(for fileURL: URL) -> [URL] {
        guard let appURLs = LSCopyApplicationURLsForURL(fileURL as CFURL, .all)?.takeRetainedValue() as? [URL] else {
            logDebug("applicationURLs returned nil for '\(fileURL.lastPathComponent)'")
            return []
        }

        logDebug("applicationURLs file='\(fileURL.lastPathComponent)' count=\(appURLs.count)")
        return appURLs
    }

    private func appendAppIfNeeded(
        from appURL: URL,
        defaultApp: URL?,
        seenBundles: inout Set<String>,
        seenAppPaths: inout Set<String>,
        apps: inout [AppInfo]
    ) {
        let normalizedURL = appURL.standardizedFileURL
        let normalizedPath = normalizedURL.path

        guard !seenAppPaths.contains(normalizedPath) else {
            logDebug("skip duplicate path='\(normalizedPath)'")
            return
        }

        seenAppPaths.insert(normalizedPath)

        guard let appInfo = makeAppInfo(
            from: normalizedURL,
            isDefault: normalizedURL == defaultApp?.standardizedFileURL
        ) else {
            logDebug("skip invalid app path='\(normalizedPath)'")
            return
        }

        guard seenBundles.insert(appInfo.bundleIdentifier).inserted else {
            logDebug("skip duplicate bundle='\(appInfo.bundleIdentifier)'")
            return
        }

        apps.append(appInfo)
    }

    // MARK: - File Opening

    /// Public alias for recordLRU — called from F3/F4 after opening with default app
    func recordUsage(bundleID: String, ext: String, appURL: URL) {
        let normalizedExt = normalizedExtensionKey(for: ext)
        logInfo("recordUsage bundle='\(bundleID)' ext='\(normalizedExt)'")
        logDebug("recordUsage app='\(appURL.lastPathComponent)'")
        recordLRU(bundleID: bundleID, ext: ext, appURL: appURL)
    }

    /// Opens file with the chosen AppInfo and records it in LRU.
    /// For remote files (sftp://) — downloads to tmp first.
    func openFile(_ fileURL: URL, with app: AppInfo) {
        logInfo("openFile file='\(fileURL.lastPathComponent)' app='\(app.name)'")

        recordLRU(bundleID: app.bundleIdentifier, ext: fileURL.pathExtension, appURL: app.url)

        let configuration = makeOpenConfiguration()

        if isRemoteFileURL(fileURL) {
            logInfo("remote file detected scheme='\(fileURL.scheme ?? "unknown")'")
            Task {
                await openRemoteFile(fileURL, with: app, configuration: configuration)
            }
            return
        }

        openLocalFile(fileURL, with: app, configuration: configuration)
    }

    private func makeOpenConfiguration() -> NSWorkspace.OpenConfiguration {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        return configuration
    }

    private func openLocalFile(_ fileURL: URL, with app: AppInfo, configuration: NSWorkspace.OpenConfiguration) {
        workspace.open([fileURL], withApplicationAt: app.url, configuration: configuration) { [weak self] runningApp, error in
            Task { @MainActor in
                guard let self else {
                    return
                }

                if let error {
                    self.logError("openLocalFile failed: \(error.localizedDescription)")
                    return
                }

                self.logDebug("openLocalFile success pid=\(runningApp?.processIdentifier ?? -1)")
            }
        }
    }

    private func openRemoteFile(_ fileURL: URL, with app: AppInfo, configuration: NSWorkspace.OpenConfiguration) async {
        do {
            logInfo("downloading remote file path='\(fileURL.path)'")
            let localURL = try await remoteConnectionManager.downloadFile(remotePath: fileURL.path)

            await MainActor.run {
                self.logInfo("remote download success local='\(localURL.path)'")
                self.openLocalFile(localURL, with: app, configuration: configuration)
            }
        } catch {
            logError("remote download failed: \(error.localizedDescription)")
        }
    }

    /// Opens file with default application
    func openFileWithDefault(_ fileURL: URL) {
        logInfo("openFileWithDefault file='\(fileURL.lastPathComponent)'")
        workspace.open(fileURL)
    }

    // MARK: - Open With Picker

    /// Shows system "Open With" picker (Choose Application...)
    func showOpenWithPicker(for fileURL: URL) {
        logDebug("showOpenWithPicker file='\(fileURL.lastPathComponent)'")
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: Constants.applicationDirectory)
        panel.allowedContentTypes = [.application]
        panel.message = "Choose an application to open '\(fileURL.lastPathComponent)'"
        panel.prompt = "Open"

        panel.begin { [weak self] response in
            guard let self else {
                return
            }

            guard response == .OK, let appURL = panel.url else {
                self.logDebug("picker cancelled")
                return
            }

            self.logInfo("picker selected app='\(appURL.lastPathComponent)'")

            let icon = self.workspace.icon(forFile: appURL.path)
            icon.size = Constants.appIconSize

            let bundleIdentifier = Bundle(url: appURL)?.bundleIdentifier ?? appURL.lastPathComponent
            let selectedApp = AppInfo(
                id: bundleIdentifier,
                name: self.fileManager.displayName(atPath: appURL.path),
                bundleIdentifier: bundleIdentifier,
                icon: icon,
                url: appURL,
                isDefault: false
            )

            self.storeUserAssociation(bundleID: bundleIdentifier, ext: fileURL.pathExtension, appURL: appURL)
            self.openFile(fileURL, with: selectedApp)
        }
    }

    // MARK: - Private Helpers

    private func makeAppInfo(from appURL: URL, isDefault: Bool) -> AppInfo? {
        let normalizedURL = appURL.standardizedFileURL
        let cacheKey = normalizedURL.path

        let descriptor: CachedAppDescriptor
        if let cached = Self.appDescriptorCache[cacheKey] {
            descriptor = cached
        } else {
            guard let bundle = Bundle(url: normalizedURL),
                  let bundleIdentifier = bundle.bundleIdentifier else {
                logDebug("makeAppInfo failed path='\(normalizedURL.path)'")
                return nil
            }

            let name = fileManager.displayName(atPath: normalizedURL.path)
            let icon = workspace.icon(forFile: normalizedURL.path)
            icon.size = Constants.appIconSize

            descriptor = CachedAppDescriptor(
                bundleIdentifier: bundleIdentifier,
                name: name,
                icon: icon,
                url: normalizedURL
            )
            Self.appDescriptorCache[cacheKey] = descriptor
        }

        logDebug("app='\(descriptor.name)'")
        logDebug("bundle='\(descriptor.bundleIdentifier)' default=\(isDefault)")
        logDebug("path='\(descriptor.url.path)'")

        return AppInfo(
            id: descriptor.bundleIdentifier,
            name: descriptor.name,
            bundleIdentifier: descriptor.bundleIdentifier,
            icon: descriptor.icon,
            url: descriptor.url,
            isDefault: isDefault
        )
    }

}
