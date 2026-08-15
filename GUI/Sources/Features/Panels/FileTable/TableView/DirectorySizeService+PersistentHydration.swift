// DirectorySizeService+PersistentHydration.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Batch hydration of directory sizes from the persistent cache before sorting.

import FileModelKit
import Foundation

extension DirectorySizeService {
    // MARK: - Batch Persistent Hydration
    func hydrateCachedSizes(for files: [CustomFile]) async -> Int {
        let candidates = files.filter {
            $0.isDirectory
                && !$0.isAppBundle
                && $0.cachedDirectorySize == nil
                && !Self.isExpensiveAutomaticRoot($0.urlValue)
                && !AppState.isAppManagedNetworkMountPath($0.urlValue)
        }
        guard !candidates.isEmpty else { return 0 }
        var resolvedByPath: [String: (file: CustomFile, url: URL)] = [:]
        resolvedByPath.reserveCapacity(candidates.count)
        for file in candidates {
            let resolvedURL = resolveURLForSizing(file.urlValue)
            resolvedByPath[resolvedURL.path] = (file, resolvedURL)
        }
        var hydrated = 0
        var missingPaths: [String] = []
        missingPaths.reserveCapacity(resolvedByPath.count)
        for (path, item) in resolvedByPath {
            guard let mtime = fileModificationTime(forResolvedPath: path, urlForScope: item.url),
                  let entry = memoryCache[path],
                  entry.size != Self.unavailableSize,
                  entry.mtime == mtime
            else {
                missingPaths.append(path)
                continue
            }
            applyCachedSize(entry.size, to: item.file)
            hydrated += 1
        }
        guard !missingPaths.isEmpty, let persistentCache else { return hydrated }
        guard let persisted = try? await persistentCache.entries(namespace: cacheNamespace, keys: missingPaths) else {
            return hydrated
        }
        var stalePaths: [String] = []
        for path in missingPaths {
            guard let item = resolvedByPath[path],
                  let stored = persisted[path],
                  let entry = try? JSONDecoder().decode(CacheEntry.self, from: stored.payload),
                  entry.size != Self.unavailableSize,
                  let mtime = fileModificationTime(forResolvedPath: path, urlForScope: item.url),
                  entry.mtime == mtime
            else {
                if persisted[path] != nil { stalePaths.append(path) }
                continue
            }
            applyCachedSize(entry.size, to: item.file)
            hydrated += 1
        }
        for path in stalePaths {
            try? await persistentCache.remove(namespace: cacheNamespace, key: path)
        }
        if hydrated > 0 {
            log.debug("[DirectorySizeService] hydrated \(hydrated) directory sizes before sorting")
        }
        return hydrated
    }

    private func applyCachedSize(_ size: Int64, to file: CustomFile) {
        file.cachedDirectorySize = size
        file.cachedShallowSize = nil
        file.sizeIsExact = true
        file.sizeCalculationStarted = false
    }
}
