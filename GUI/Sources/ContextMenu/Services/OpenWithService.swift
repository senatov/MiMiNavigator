    // OpenWithService.swift
    // MiMiNavigator
    //
    // Created by Iakov Senatov on 04.02.2026.
    // Copyright © 2026 Senatov. All rights reserved.
    // Description: Service for "Open With" functionality - fetches available applications

    import AppKit
    import Foundation
    import UniformTypeIdentifiers

    // MARK: - Application Info
    /// Represents an application that can open a file
    struct AppInfo: Identifiable, Hashable {
        let id: String
        let name: String
        let bundleIdentifier: String
        let icon: NSImage
        let url: URL
        let isDefault: Bool

        func hash(into hasher: inout Hasher) {
            hasher.combine(bundleIdentifier)
        }

        static func == (lhs: AppInfo, rhs: AppInfo) -> Bool {
            lhs.bundleIdentifier == rhs.bundleIdentifier
        }
    }

    // MARK: - Open With Service
    /// Fetches applications capable of opening specific file types
    @MainActor
    final class OpenWithService {

        static let shared = OpenWithService()
        private let workspace = NSWorkspace.shared

        // MARK: - LRU recent apps (max 5, per-extension key)
        private let lruDefaultsKey = "openWithLRU"
        private let lruAppURLsKey  = "openWithAppURLs"   // bundleID → app path, for "Other..." picks
        private let lruMaxCount = 5

        // MARK: - Apps cache (per absolute file path)
        nonisolated(unsafe) private static var appsCache = NSCache<NSString, NSArray>()

        private init() {
            OpenWithService.appsCache.countLimit = 64
            log.debug("\(#function) OpenWithService initialized")
        }

        // MARK: - LRU helpers

        /// Returns bundle IDs of recently-used apps for a given file extension, newest first
        private func lruBundles(for ext: String) -> [String] {
            let dict = MiMiDefaults.shared.dictionary(forKey: lruDefaultsKey) as? [String: [String]] ?? [:]
            return dict[ext.lowercased()] ?? []
        }

        /// Records that `bundleID` was used to open a file with `ext`
        private func recordLRU(bundleID: String, ext: String, appURL: URL? = nil) {
            let key = ext.lowercased()
            var dict = MiMiDefaults.shared.dictionary(forKey: lruDefaultsKey) as? [String: [String]] ?? [:]
            var list = dict[key] ?? []
            list.removeAll { $0 == bundleID }   // deduplicate
            list.insert(bundleID, at: 0)        // newest first
            if list.count > lruMaxCount { list = Array(list.prefix(lruMaxCount)) }
            dict[key] = list
            MiMiDefaults.shared.set(dict, forKey: lruDefaultsKey)
            // Persist app URL so "Other..." picks can be restored in the list
            if let appURL {
                var urls = MiMiDefaults.shared.dictionary(forKey: lruAppURLsKey) as? [String: String] ?? [:]
                urls[bundleID] = appURL.path
                MiMiDefaults.shared.set(urls, forKey: lruAppURLsKey)
            }
            log.debug("\(#function) LRU updated ext='\(key)' list=\(list)")
        }

        // MARK: - Get Applications for File

        /// Returns list of applications that can open the given file
        func getApplications(for fileURL: URL) -> [AppInfo] {
            // Cache by file extension instead of full path to avoid thousands of LaunchServices calls
            let extKey = fileURL.pathExtension.lowercased()
            let cacheKey = extKey as NSString

            if let cached = OpenWithService.appsCache.object(forKey: cacheKey) as? [AppInfo] {
                return cached
            }
            guard UTType(filenameExtension: fileURL.pathExtension) != nil else {
                //log.warning("\(#function) unknown UTType for ext='\(fileURL.pathExtension)', using fallback editors")
                return getAllEditors()
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
                log.warning("\(#function) LSCopyApplicationURLsForURL returned nil")
            }

            // Sort: default app first, then LRU recency, then alphabetically
            let recentBundles = lruBundles(for: fileURL.pathExtension)

            // Add LRU-picked apps that are missing from the LS list (e.g. picked via "Other...")
            let knownBundles = Set(apps.map(\.bundleIdentifier))
            let savedURLs = MiMiDefaults.shared.dictionary(forKey: lruAppURLsKey) as? [String: String] ?? [:]
            for bundleID in recentBundles where !knownBundles.contains(bundleID) {
                if let path = savedURLs[bundleID] {
                    let url = URL(fileURLWithPath: path)
                    if let info = makeAppInfo(from: url, isDefault: url == defaultApp) {
                        apps.append(info)
                        log.debug("\(#function) restored LRU app '\(info.name)' from saved path")
                    }
                }
            }

            apps.sort { lhs, rhs in
                if lhs.isDefault != rhs.isDefault { return lhs.isDefault }
                let lhsIdx = recentBundles.firstIndex(of: lhs.bundleIdentifier) ?? Int.max
                let rhsIdx = recentBundles.firstIndex(of: rhs.bundleIdentifier) ?? Int.max
                if lhsIdx != rhsIdx { return lhsIdx < rhsIdx }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }

            log.info(
                "\(#function) found \(apps.count) apps for ext='\(fileURL.pathExtension)' default='\(defaultApp?.lastPathComponent ?? "none")'"
            )
            OpenWithService.appsCache.setObject(apps as NSArray, forKey: cacheKey)
            return apps
        }

        // MARK: - Open File With Application

        /// Public alias for recordLRU — called from F3/F4 after opening with default app
        func recordUsage(bundleID: String, ext: String, appURL: URL) {
            recordLRU(bundleID: bundleID, ext: ext, appURL: appURL)
        }

        /// Opens file with the chosen AppInfo and records it in LRU
        func openFile(_ fileURL: URL, with app: AppInfo) {
            log.info("\(#function) file='\(fileURL.lastPathComponent)' app='\(app.name)' bundle=\(app.bundleIdentifier)")
            recordLRU(bundleID: app.bundleIdentifier, ext: fileURL.pathExtension)

            let config = NSWorkspace.OpenConfiguration()
            config.activates = true

            workspace.open([fileURL], withApplicationAt: app.url, configuration: config) { runningApp, error in
                if let error = error {
                    log.error("\(#function) FAILED: \(error.localizedDescription)")
                } else {
                    log.debug("\(#function) SUCCESS opened with pid=\(runningApp?.processIdentifier ?? -1)")
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
                        self?.recordLRU(bundleID: bundleID, ext: fileURL.pathExtension, appURL: appURL)
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
                guard FileManager.default.fileExists(atPath: path) else { return nil }
                return makeAppInfo(from: url, isDefault: false)
            }

            //log.debug("\(#function) returning \(editors.count) fallback editors")
            return editors
        }
    }
