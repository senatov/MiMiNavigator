    //
    //  FileIconCache.swift
    //  MiMiNavigator
    //
    //  Created by Iakov Senatov on 11.03.2026.
    //  Copyright © 2026 Senatov. All rights reserved.
    //

    import AppKit

    /// Global icon cache to avoid repeated NSWorkspace icon lookups.
    @MainActor
    final class FileIconCache {

        static let shared = FileIconCache()

        private let cache = NSCache<NSString, NSImage>()

        private init() {
            // Limit number of cached icons to avoid unbounded memory growth
            cache.countLimit = 2000

            // Rough memory cap (~50 MB). NSCache may evict earlier under pressure.
            cache.totalCostLimit = 50 * 1024 * 1024
        }

        func icon(for path: String) -> NSImage {
            if let cached = cache.object(forKey: path as NSString) {
                return cached
            }

            let icon = NSWorkspace.shared.icon(forFile: path)
            cache.setObject(icon, forKey: path as NSString)
            return icon
        }

        func clear() {
            cache.removeAllObjects()
        }
    }
