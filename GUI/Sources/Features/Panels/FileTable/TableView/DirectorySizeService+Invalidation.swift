// DirectorySizeService+Invalidation.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Invalidates directory-size caches after filesystem mutations.

import Foundation

// MARK: - Directory Size Cache Invalidation
extension DirectorySizeService {
    func invalidateCache(affectedBy urls: [URL]) async {
        let changedPaths = Set(urls.map { resolveURLForSizing($0).path }.filter { !$0.isEmpty })
        guard !changedPaths.isEmpty else { return }
        let isRelated: (String) -> Bool = { cachedPath in
            changedPaths.contains { changedPath in
                cachedPath == changedPath
                    || cachedPath.hasPrefix(changedPath + "/")
                    || changedPath.hasPrefix(cachedPath + "/")
            }
        }
        let memoryCount = memoryCache.count
        memoryCache = memoryCache.filter { !isRelated($0.key) }
        permanentlyUnavailable = Set(permanentlyUnavailable.filter { !isRelated($0) })
        for path in inFlightTasks.keys.filter(isRelated) {
            inFlightTasks[path]?.cancel()
            inFlightCancellation[path]?.cancel()
            inFlightTasks[path] = nil
            inFlightCancellation[path] = nil
        }
        if let persistentCache {
            for path in changedPaths {
                try? await persistentCache.remove(namespace: cacheNamespace, keyPrefix: path)
                for ancestor in Self.ancestorPaths(of: path) {
                    try? await persistentCache.remove(namespace: cacheNamespace, key: ancestor)
                }
            }
        }
        log.info("[DirectorySizeService] invalidated \(memoryCount - memoryCache.count) memory entries for \(changedPaths.count) changed path(s)")
    }

    nonisolated private static func ancestorPaths(of path: String) -> [String] {
        var ancestors: [String] = []
        var current = (path as NSString).deletingLastPathComponent
        while !current.isEmpty && current != "/" {
            ancestors.append(current)
            let parent = (current as NSString).deletingLastPathComponent
            guard parent != current else { break }
            current = parent
        }
        return ancestors
    }
}
