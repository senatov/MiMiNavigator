// OpenWithService.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 04.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Service for "Open With" functionality - fetches available applications

import AppKit
import FileModelKit
import Foundation
import UniformTypeIdentifiers

// MARK: - Open With Service
/// Fetches applications capable of opening specific file types
@MainActor
final class OpenWithService {

    static let shared = OpenWithService()
    private let workspace = NSWorkspace.shared

    private enum Constants {
        static let noExtensionKey = "__noext__"
    }

    // MARK: - LRU recent apps (max 5, per-extension key)
    private let lruDefaultsKey = "openWithLRU"
    private let lruAppURLsKey = "openWithAppURLs"  // bundleID → app path, for "Other..." picks
    private let lruMaxCount = 5

    // MARK: - Apps cache (per absolute file path)
    private static let appsCache = NSCache<NSString, NSArray>()

    private init() {
        log.debug(#function)
        OpenWithService.appsCache.countLimit = 64
        log.debug("\(#function) OpenWithService initialized")
    }

    // MARK: - Key helpers

    private func normalizedExtensionKey(for ext: String) -> String {
        let normalized = ext.lowercased()
        return normalized.isEmpty ? Constants.noExtensionKey : normalized
    }

    private func savedAppURLs() -> [String: String] {
        MiMiDefaults.shared.dictionary(forKey: lruAppURLsKey) as? [String: String] ?? [:]
    }

    // MARK: - LRU helpers

    /// Returns bundle IDs of recently-used apps for a given file extension, newest first
    private func lruBundles(for ext: String) -> [String] {
        log.debug(#function)
        let key = normalizedExtensionKey(for: ext)
        let dict = MiMiDefaults.shared.dictionary(forKey: lruDefaultsKey) as? [String: [String]] ?? [:]
        let list = dict[key] ?? []
        log.debug("\(#function) key='\(key)' bundles=\(list)")
        return list
    }

    /// Records that `bundleID` was used to open a file with `ext`
    private func recordLRU(bundleID: String, ext: String, appURL: URL? = nil) {
        log.debug(#function)
        let key = normalizedExtensionKey(for: ext)
        var dict = MiMiDefaults.shared.dictionary(forKey: lruDefaultsKey) as? [String: [String]] ?? [:]
        var list = dict[key] ?? []
        list.removeAll { $0 == bundleID }
        list.insert(bundleID, at: 0)
        if list.count > lruMaxCount {
            list = Array(list.prefix(lruMaxCount))
        }
        dict[key] = list
        MiMiDefaults.shared.set(dict, forKey: lruDefaultsKey)
        if let appURL {
            var urls = savedAppURLs()
            urls[bundleID] = appURL.path
            MiMiDefaults.shared.set(urls, forKey: lruAppURLsKey)
            log.debug("\(#function) stored appURL='\(appURL.path)' for bundle='\(bundleID)'")
        }
        invalidateCache(for: ext)
        log.info("\(#function) LRU updated key='\(key)' top='\(bundleID)' list=\(list)")
    }
    // MARK: - Cache Invalidation
    /// Notification posted when Open With LRU order changes; userInfo["ext"] contains the extension
    static let cacheInvalidatedNotification = Notification.Name("OpenWithService.cacheInvalidated")
    /// Removes cached app list for the given extension so it is rebuilt with fresh LRU order
    func invalidateCache(for ext: String) {
        let normalizedExt = normalizedExtensionKey(for: ext)
        OpenWithService.appsCache.removeObject(forKey: normalizedExt as NSString)
        NotificationCenter.default.post(name: Self.cacheInvalidatedNotification, object: nil, userInfo: ["ext": normalizedExt])
        log.debug("\(#function) cache invalidated for ext='\(normalizedExt)'")
    }

    // MARK: - Get Applications for File

    /// Returns list of applications that can open the given file
    func getApplications(for fileURL: URL) -> [AppInfo] {
        log.debug(#function)
        let ext = fileURL.pathExtension
        let normalizedExt = normalizedExtensionKey(for: ext)
        let cacheKey = normalizedExt as NSString
        log.debug("\(#function) file='\(fileURL.lastPathComponent)' ext='\(normalizedExt)'")

        if let cached = OpenWithService.appsCache.object(forKey: cacheKey) as? [AppInfo] {
            return cached
        }
        let defaultApp = workspace.urlForApplication(toOpen: fileURL)
        var apps: [AppInfo] = []
        var seenBundles = Set<String>()

        // Get apps from Launch Services
        if let appURLs = LSCopyApplicationURLsForURL(fileURL as CFURL, .all)?.takeRetainedValue() as? [URL] {
            log.debug("\(#function) LSCopyApplicationURLsForURL returned \(appURLs.count) apps")

            for appURL in appURLs {
                if let appInfo = makeAppInfo(from: appURL, isDefault: appURL == defaultApp) {
                    if !seenBundles.contains(appInfo.bundleIdentifier) {
                        seenBundles.insert(appInfo.bundleIdentifier)
                        apps.append(appInfo)
                    }
                }
            }
        } else {
            log.debug("\(#function) LSCopyApplicationURLsForURL returned nil")
        }

        // Sort: default app first, then LRU recency, then alphabetically
        let recentBundles = lruBundles(for: ext)
        log.debug("\(#function) recentBundles=\(recentBundles)")

        // Add LRU-picked apps that are missing from the LS list (e.g. picked via "Other...")
        let knownBundles = Set(apps.map(\.bundleIdentifier))
        let savedURLs = savedAppURLs()
        for bundleID in recentBundles where !knownBundles.contains(bundleID) {
            if let path = savedURLs[bundleID], FileManager.default.fileExists(atPath: path) {
                let url = URL(fileURLWithPath: path)
                if let info = makeAppInfo(from: url, isDefault: url == defaultApp) {
                    apps.append(info)
                    log.debug("\(#function) restored LRU app '\(info.name)' from saved path")
                }
            }
        }

        // Sort priority:
        // 1. LRU-first (most recently used) — user's explicit choice wins
        // 2. Default app (if not already LRU-first)
        // 3. Alphabetical
        apps.sort { lhs, rhs in
            let lhsLRU = recentBundles.firstIndex(of: lhs.bundleIdentifier) ?? Int.max
            let rhsLRU = recentBundles.firstIndex(of: rhs.bundleIdentifier) ?? Int.max
            if lhsLRU != rhsLRU { return lhsLRU < rhsLRU }
            if lhs.isDefault != rhs.isDefault { return lhs.isDefault }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
        let orderedBundles = apps.map(\.bundleIdentifier)
        log.info("\(#function) found \(apps.count) apps for ext='\(normalizedExt)'")
        log.info("\(#function) default='\(defaultApp?.lastPathComponent ?? "none")' ordered=\(orderedBundles)")
        OpenWithService.appsCache.setObject(apps as NSArray, forKey: cacheKey)
        return apps
    }

    // MARK: - Open File With Application

    /// Public alias for recordLRU — called from F3/F4 after opening with default app
    func recordUsage(bundleID: String, ext: String, appURL: URL) {
        log.info("\(#function) bundle='\(bundleID)' ext='\(normalizedExtensionKey(for: ext))' app='\(appURL.lastPathComponent)'")
        recordLRU(bundleID: bundleID, ext: ext, appURL: appURL)
    }

    /// Opens file with the chosen AppInfo and records it in LRU.
    /// For remote files (sftp://) — downloads to tmp first.
    func openFile(_ fileURL: URL, with app: AppInfo) {
        log.info("\(#function) file='\(fileURL.lastPathComponent)' app='\(app.name)'")
        recordLRU(bundleID: app.bundleIdentifier, ext: fileURL.pathExtension, appURL: app.url)
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        if fileURL.scheme == "sftp" || fileURL.scheme == "ftp" {
            Task {
                do {
                    let localURL = try await RemoteConnectionManager.shared.downloadFile(remotePath: fileURL.path)
                    await MainActor.run {
                        NSWorkspace.shared.open([localURL], withApplicationAt: app.url, configuration: config) { _, err in
                            if let err {
                                log.error("\(#function) open FAILED: \(err.localizedDescription)")
                            }
                        }
                    }
                } catch {
                    log.error("\(#function) remote download FAILED: \(error.localizedDescription)")
                }
            }
            return
        }
        workspace.open([fileURL], withApplicationAt: app.url, configuration: config) { runningApp, error in
            if let error {
                log.error("\(#function) FAILED: \(error.localizedDescription)")
            } else {
                log.debug("\(#function) SUCCESS pid=\(runningApp?.processIdentifier ?? -1)")
            }
        }
    }

    /// Opens file with default application
    func openFileWithDefault(_ fileURL: URL) {
        log.info("\(#function) file='\(fileURL.lastPathComponent)'")
        workspace.open(fileURL)
    }

    // MARK: - Show "Open With" System Dialog

    /// Shows system "Open With" picker (Choose Application...)
    func showOpenWithPicker(for fileURL: URL) {
        log.debug("\(#function) file='\(fileURL.lastPathComponent)'")
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.application]
        panel.message = "Choose an application to open '\(fileURL.lastPathComponent)'"
        panel.prompt = "Open"

        panel.begin { [weak self] response in
            if response == .OK, let appURL = panel.url {
                log.info("\(#function) user selected app='\(appURL.lastPathComponent)'")
                // Record in LRU with app URL so it appears in the list next time
                if let bundleID = Bundle(url: appURL)?.bundleIdentifier {
                    self?.recordUsage(bundleID: bundleID, ext: fileURL.pathExtension, appURL: appURL)
                }
                let config = NSWorkspace.OpenConfiguration()
                config.activates = true
                NSWorkspace.shared.open([fileURL], withApplicationAt: appURL, configuration: config)
            } else {
                log.debug("\(#function) user cancelled picker")
            }
        }
    }

    // MARK: - Private Helpers

    private func makeAppInfo(from appURL: URL, isDefault: Bool) -> AppInfo? {
        guard let bundle = Bundle(url: appURL),
            let bundleIdentifier = bundle.bundleIdentifier
        else {
            return nil
        }

        let name = FileManager.default.displayName(atPath: appURL.path)
        let icon = workspace.icon(forFile: appURL.path)
        icon.size = NSSize(width: 16, height: 16)
        log.debug("\(#function) app='\(name)' bundle='\(bundleIdentifier)' default=\(isDefault)")

        return AppInfo(
            id: bundleIdentifier,
            name: name,
            bundleIdentifier: bundleIdentifier,
            icon: icon,
            url: appURL,
            isDefault: isDefault
        )
    }

    /// Fallback: common text editors for unknown file types
    private func getAllEditors() -> [AppInfo] {
        let editorPaths = [
            "/System/Applications/TextEdit.app",
            "/Applications/Visual Studio Code.app",
            "/Applications/Sublime Text.app",
            "/Applications/BBEdit.app",
        ]
        let editors = editorPaths.compactMap { path -> AppInfo? in
            let url = URL(fileURLWithPath: path)
            guard FileManager.default.fileExists(atPath: path) else {
                return nil
            }
            return makeAppInfo(from: url, isDefault: false)
        }
        log.debug("\(#function) editors=\(editors.map(\.name))")
        return editors
    }
}
