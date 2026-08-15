// DirectorySizeService+PersistentHydration.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Batch hydration of directory sizes from SQLite before sorting.

import FileModelKit
import Foundation

extension DirectorySizeService {
    // MARK: - Batch Persistent Hydration
    func hydrateCachedSizes(for files: [CustomFile]) async -> Int {
        let candidates = files.filter {
            ($0.isDirectory || $0.isSymbolicDirectory)
                && !$0.isAppBundle
                && $0.cachedDirectorySize == nil
                && !Self.isExpensiveAutomaticRoot($0.urlValue)
                && !AppState.isAppManagedNetworkMountPath($0.urlValue)
        }
        guard !candidates.isEmpty else { return 0 }
        var items: [String: (file: CustomFile, url: URL)] = [:]
        for file in candidates {
            let url = resolveURLForSizing(file.urlValue)
            items[url.path] = (file, url)
        }
        var hydrated = 0
        var missing: [String] = []
        for (path, item) in items {
            guard let mtime = fileModificationTime(forResolvedPath: path, urlForScope: item.url),
                  let entry = memoryCache[path], entry.size != Self.unavailableSize, entry.mtime == mtime
            else {
                missing.append(path)
                continue
            }
            applyCachedSize(entry.size, to: item.file)
            hydrated += 1
        }
        guard !missing.isEmpty, let persistentCache,
              let persisted = try? await persistentCache.entries(
                namespace: cacheNamespace, keys: missing, refreshingAccess: false
              )
        else { return hydrated }
        for path in missing {
            guard let item = items[path], let stored = persisted[path],
                  let entry = try? JSONDecoder().decode(CacheEntry.self, from: stored.payload),
                  entry.size != Self.unavailableSize,
                  let mtime = fileModificationTime(forResolvedPath: path, urlForScope: item.url), entry.mtime == mtime
            else { continue }
            memoryCache[path] = entry
            applyCachedSize(entry.size, to: item.file)
            hydrated += 1
        }
        if hydrated > 0 { log.debug("[DirectorySizeService] batch hydrated \(hydrated) directory sizes") }
        return hydrated
    }

    private func applyCachedSize(_ size: Int64, to file: CustomFile) {
        file.cachedDirectorySize = size
        file.cachedShallowSize = nil
        file.sizeIsExact = true
        file.sizeCalculationStarted = false
    }
}
