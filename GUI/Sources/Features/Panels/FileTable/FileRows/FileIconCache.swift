    //
    //  FileIconCache.swift
    //  MiMiNavigator
    //
    //  Created by Iakov Senatov on 11.03.2026.
    //  Copyright © 2026 Senatov. All rights reserved.
    //

    import AppKit
    import UniformTypeIdentifiers

    /// Global icon cache to avoid repeated NSWorkspace icon lookups.
    final class FileIconCache: @unchecked Sendable {

        static let shared = FileIconCache()

        private let cache = NSCache<NSString, NSImage>()

        private init() {
            // Number of unique icon types is usually small (<200), so a lower limit is sufficient
            cache.countLimit = 512

            // Rough memory cap (~50 MB). NSCache may evict earlier under pressure.
            cache.totalCostLimit = 50 * 1024 * 1024
        }

        /// Derives a stable cache key based on UTType instead of full path.
        /// This prevents thousands of duplicate icons while matching Finder behavior.
        private func cacheKey(for url: URL, isDirectory: Bool) -> NSString {
            if isDirectory {
                return "folder" as NSString
            }

            if let type = UTType(filenameExtension: url.pathExtension) {
                return type.identifier as NSString
            }

            if url.pathExtension.isEmpty {
                return "public.data" as NSString
            }

            return url.pathExtension.lowercased() as NSString
        }

        /// Preferred API: fetch icon using URL
        func icon(for url: URL, isDirectory: Bool? = nil) -> NSImage {

            // Caller may pass known isDirectory to avoid filesystem lookup (symlinks)
            let isDirectory = isDirectory ?? url.hasDirectoryPath

            let key = cacheKey(for: url, isDirectory: isDirectory)

            if let cached = cache.object(forKey: key) {
                return cached
            }

            let icon: NSImage

            // Determine icon by content type instead of filesystem lookup
            if isDirectory {

                // Bundle directories (.app, .framework, .bundle, etc.)
                // should display their custom icon like Finder.
                if !url.pathExtension.isEmpty,
                    let type = UTType(filenameExtension: url.pathExtension),
                    type.conforms(to: .bundle)
                {

                    icon = NSWorkspace.shared.icon(forFile: url.path)

                } else {
                    icon = NSWorkspace.shared.icon(for: .folder)
                }

            } else if let type = UTType(filenameExtension: url.pathExtension) {

                icon = NSWorkspace.shared.icon(for: type)

            } else {

                icon = NSWorkspace.shared.icon(for: .data)
            }
            // Copy icon before caching because NSImage instances from NSWorkspace are mutable
            let iconCopy = icon.copy() as! NSImage
            cache.setObject(iconCopy, forKey: key)
            return iconCopy
        }

        /// Compatibility helper for older call sites still passing String paths
        func icon(for path: String) -> NSImage {
            icon(for: URL(fileURLWithPath: path))
        }

        func clear() {
            cache.removeAllObjects()
        }
    }
