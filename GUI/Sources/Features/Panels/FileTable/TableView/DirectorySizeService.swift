//
//  DirectorySizeService.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 13.03.2026.
//

import AppKit
import CacheKit
import Foundation

/// Asynchronous, bounded directory sizing with memory and persistent caches.
actor DirectorySizeService {
    // MARK: - Singleton
    static let shared = DirectorySizeService()
    private nonisolated static let cancellation = DirectorySizeCancellationState()
    // MARK: - Constants
    /// Special value meaning: size could not be determined (permission/sandbox/virtual FS/unreadable).
    /// IMPORTANT: Do not format/display this as a real size.
    static let unavailableSize: Int64 = -1

    /// Best-effort wrapper for sandboxed locations.
    /// If the URL is not security-scoped, startAccessingSecurityScopedResource() returns false and we still try.
    nonisolated private func withSecurityScope<T>(_ url: URL, _ work: () throws -> T) rethrows -> T {
        let isFileURL = url.isFileURL
        let didStart = isFileURL ? url.startAccessingSecurityScopedResource() : false
        defer {
            if didStart {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try work()
    }

    // MARK: - Concurrency
    /// Limit simultaneous directory scans
    private let semaphore = DispatchSemaphore(value: 2)

    /// Background queue for directory traversal
    private let queue = DispatchQueue(
        label: "MiMiNavigator.dirsize",
        qos: .utility,
        attributes: .concurrent)

    // MARK: - Cache
    /// In‑memory cache
    private var memoryCache: [String: CacheEntry] = [:]

    /// Paths confirmed unreadable (no perms / sandbox / virtual FS).
    /// Never retry these — they won't become readable without a restart.
    private var permanentlyUnavailable: Set<String> = []

    /// Tracks directory size calculations currently in progress
    /// Prevents the same directory from being scanned multiple times simultaneously.
    private var inFlightTasks: [String: Task<Int64, Never>] = [:]
    private var inFlightCancellation: [String: DirectorySizeCancellationState] = [:]

    private let persistentCache = ApplicationPersistentCache.shared
    private let legacyCacheURL: URL
    private let cacheNamespace = "directory-size-v1"
    private let cacheEntryLimit = 512
    private let cacheMaxIdleAge: TimeInterval = 30 * 60
    private let persistentLifetime: TimeInterval = 7 * 24 * 60 * 60

    // MARK: - Cache Entry
    private struct CacheEntry: Codable {
        let size: Int64
        let mtime: TimeInterval
        var lastAccess: TimeInterval?
    }

    // MARK: - Init
    private init() {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("MiMiNavigator", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        legacyCacheURL = dir.appendingPathComponent("dirsize.cache")
        Task { await self.migrateLegacyDiskCache() }
        self.registerVolumeMountObserver()
    }

    // MARK: - Volume mount observer
    /// Clears permanentlyUnavailable + memoryCache for /Volumes paths when a disk mounts.
    /// NSWorkspace posts to its own notificationCenter (not NotificationCenter.default).
    /// nonisolated so it can be called from init; forwards mutations into actor via Task.
    nonisolated private func registerVolumeMountObserver() {
        // Raw string name avoids @MainActor isolation on NSWorkspace.didMountVolumeNotification
        let note = Notification.Name("NSWorkspaceDidMountNotification")
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: note,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { await self.purgeVolumesCache() }
        }
    }

    /// Actor-isolated mutation — safe to call from Task
    private func purgeVolumesCache() {
        let deadPaths = permanentlyUnavailable.filter { $0.hasPrefix("/Volumes/") }
        let deadCache = memoryCache.keys.filter { $0.hasPrefix("/Volumes/") }
        permanentlyUnavailable.subtract(deadPaths)
        deadCache.forEach { memoryCache.removeValue(forKey: $0) }
        if !deadPaths.isEmpty || !deadCache.isEmpty {
            log.info("\(#function) vol mounted — purged \(deadPaths.count) unavail + \(deadCache.count) cache entries")
        }
    }

    // MARK: - Public API
    /// Request directory size.
    /// Returns cached value immediately if available.
    func requestSize(for url: URL) async -> Int64 {
        guard !Self.cancellation.isCancelled else { return Self.unavailableSize }
        let resolvedURL = resolveURLForSizing(url)
        guard !Self.isExpensiveAutomaticRoot(resolvedURL) else {
            log.info("[DirectorySizeService] automatic scan skipped for expensive root: \(resolvedURL.path)")
            return Self.unavailableSize
        }
        guard !AppState.isAppManagedNetworkMountPath(resolvedURL) else {
            return Self.unavailableSize
        }
        let key = cacheKey(for: resolvedURL)
        // fast bail: already known unreadable — don't even try
        if permanentlyUnavailable.contains(key) {
            return Self.unavailableSize
        }
        if let cached = await cachedSize(for: resolvedURL) {
            return cached
        }
        if let existingTask = inFlightTask(for: key) {
            return await existingTask.value
        }
        let cancellation = DirectorySizeCancellationState()
        let task = makeSizeTask(for: resolvedURL, cancellation: cancellation)
        inFlightCancellation[key] = cancellation
        setInFlightTask(task, for: key)
        let result = await task.value
        if inFlightCancellation[key] === cancellation {
            clearInFlightTask(for: key)
            inFlightCancellation[key] = nil
        }
        // mark as permanently unavailable if unreadable
        if result == Self.unavailableSize, !cancellation.isCancelled {
            permanentlyUnavailable.insert(key)
            log.debug("\(#function) marked permanently unavailable: \(key)")
        }
        return result
    }

    // MARK: - Request helpers

    private func resolveURLForSizing(_ url: URL) -> URL {
        // Resolve symlinks for consistent cache keys and calculation
        return url.resolvingSymlinksInPath()
    }
    // MARK: - File Attribute Helper

    private func fileModificationTime(forResolvedPath path: String, urlForScope: URL) -> TimeInterval? {
        let attrs: [FileAttributeKey: Any]?
        attrs = try? withSecurityScope(urlForScope) {
            try FileManager.default.attributesOfItem(atPath: path)
        }
        guard let attrs, let mtime = attrs[.modificationDate] as? Date else {
            return nil
        }
        return mtime.timeIntervalSince1970
    }

    private func cacheKey(for url: URL) -> String {
        url.path
    }

    private func inFlightTask(for path: String) -> Task<Int64, Never>? {
        inFlightTasks[path]
    }

    private func setInFlightTask(_ task: Task<Int64, Never>, for path: String) {
        inFlightTasks[path] = task
    }

    private func clearInFlightTask(for path: String) {
        inFlightTasks[path] = nil
    }

    private func makeSizeTask(for url: URL, cancellation: DirectorySizeCancellationState) -> Task<Int64, Never> {
        Task { [weak self] () -> Int64 in
            guard let self else { return Self.unavailableSize }
            let size = await self.computeSizeOnBackgroundQueue(for: url, cancellation: cancellation)
            await self.storeCache(size: size, for: url)
            return size
        }
    }

    // MARK: - Shutdown
    func shutdown() {
        Self.cancellation.cancel()
        for task in inFlightTasks.values {
            task.cancel()
        }
        for cancellation in inFlightCancellation.values {
            cancellation.cancel()
        }
        inFlightTasks.removeAll()
        inFlightCancellation.removeAll()
        log.info("[DirectorySizeService] shutdown requested")
    }

    // MARK: - Cancel Path
    func cancelRequests(under rootURL: URL) {
        let rootPath = resolveURLForSizing(rootURL).path
        let matchingKeys = inFlightTasks.keys.filter { $0 == rootPath || $0.hasPrefix(rootPath + "/") }
        for key in matchingKeys {
            inFlightTasks[key]?.cancel()
            inFlightCancellation[key]?.cancel()
            inFlightTasks[key] = nil
            inFlightCancellation[key] = nil
        }
        if !matchingKeys.isEmpty {
            log.info("[DirectorySizeService] cancelled \(matchingKeys.count) request(s) under \(rootPath)")
        }
    }

    // MARK: - Cache Pruning
    func pruneCache(keeping roots: [URL]) async {
        let now = Date().timeIntervalSince1970
        let normalizedRoots = roots.map { resolveURLForSizing($0).path }
        let before = memoryCache.count
        memoryCache = memoryCache.filter { path, entry in
            let isRetained = normalizedRoots.contains { path == $0 || path.hasPrefix($0 + "/") }
            let access = entry.lastAccess ?? entry.mtime
            return isRetained && now - access <= cacheMaxIdleAge
        }
        if memoryCache.count > cacheEntryLimit {
            let overflow = memoryCache.count - cacheEntryLimit
            let oldest =
                memoryCache.sorted {
                    ($0.value.lastAccess ?? $0.value.mtime) < ($1.value.lastAccess ?? $1.value.mtime)
                }
                .prefix(overflow)
            for item in oldest { memoryCache.removeValue(forKey: item.key) }
        }
        permanentlyUnavailable = Set(
            permanentlyUnavailable.filter { path in
                normalizedRoots.contains { path == $0 || path.hasPrefix($0 + "/") }
            }
        )
        let removed = before - memoryCache.count
        if removed > 0 {
            log.info(
                "[DirectorySizeService] pruned \(removed) stale entries; "
                    + "retained=\(memoryCache.count) contextRoots=\(normalizedRoots.count)"
            )
        }
        let policy = CachePruningPolicy(
            retainedKeyPrefixes: normalizedRoots,
            maximumIdleAge: persistentLifetime,
            maximumEntryCount: 4_096,
            maximumTotalCost: 16 * 1_024 * 1_024
        )
        if let diskRemoved = try? await persistentCache?.prune(namespace: cacheNamespace, policy: policy),
            diskRemoved > 0
        {
            log.info("[DirectorySizeService] pruned \(diskRemoved) persistent entries")
        }
    }

    private func computeSizeOnBackgroundQueue(
        for url: URL,
        cancellation: DirectorySizeCancellationState
    ) async -> Int64 {
        await withCheckedContinuation { (continuation: CheckedContinuation<Int64, Never>) in
            queue.async { [semaphore, weak self] in
                guard let self else {
                    continuation.resume(returning: Self.unavailableSize)
                    return
                }
                semaphore.wait()
                defer { semaphore.signal() }
                guard !Self.cancellation.isCancelled, !cancellation.isCancelled else {
                    continuation.resume(returning: Self.unavailableSize)
                    return
                }
                // Phase 2 + 3 native calculation (security-scoped best-effort)
                let size: Int64 = self.withSecurityScope(url) {
                    DirectorySizeNativeCalculator.directorySize(url, cancellation: cancellation)
                }
                continuation.resume(returning: size)
            }
        }
    }

    // MARK: - Cache Lookup

    private func cachedSize(for url: URL) async -> Int64? {
        let path = url.resolvingSymlinksInPath().path
        guard let mtime = fileModificationTime(forResolvedPath: path, urlForScope: url.resolvingSymlinksInPath()) else {
            return nil
        }
        if var entry = memoryCache[path], entry.size != Self.unavailableSize, entry.mtime == mtime {
            entry.lastAccess = Date().timeIntervalSince1970
            memoryCache[path] = entry
            return entry.size
        }
        memoryCache[path] = nil
        guard let persisted = try? await persistentCache?.entry(namespace: cacheNamespace, key: path),
            let entry = try? JSONDecoder().decode(CacheEntry.self, from: persisted.payload),
            entry.size != Self.unavailableSize,
            entry.mtime == mtime
        else {
            try? await persistentCache?.remove(namespace: cacheNamespace, key: path)
            return nil
        }
        var refreshed = entry
        refreshed.lastAccess = Date().timeIntervalSince1970
        memoryCache[path] = refreshed
        log.debug("[DirectorySizeService] persistent hit path='\(url.lastPathComponent)'")
        return refreshed.size
    }

    // MARK: - Cache Store

    private func storeCache(size: Int64, for url: URL) async {
        // Do not cache "unavailable" results.
        guard size != Self.unavailableSize else { return }
        let resolvedURL = resolveURLForSizing(url)
        let path = resolvedURL.path
        guard let mtime = fileModificationTime(forResolvedPath: path, urlForScope: resolvedURL) else {
            return
        }
        let entry = CacheEntry(size: size, mtime: mtime, lastAccess: Date().timeIntervalSince1970)
        memoryCache[path] = entry
        if let payload = try? JSONEncoder().encode(entry) {
            try? await persistentCache?
                .set(
                    namespace: cacheNamespace,
                    key: path,
                    payload: payload,
                    expiresAt: Date().addingTimeInterval(persistentLifetime)
                )
        }
    }

    // MARK: - Legacy Cache Migration
    private func migrateLegacyDiskCache() async {
        guard FileManager.default.fileExists(atPath: legacyCacheURL.path),
            let data = try? Data(contentsOf: legacyCacheURL),
            let decoded = try? JSONDecoder().decode([String: CacheEntry].self, from: data),
            let persistentCache
        else { return }
        do {
            for (path, entry) in decoded {
                let payload = try JSONEncoder().encode(entry)
                try await persistentCache.set(
                    namespace: cacheNamespace,
                    key: path,
                    payload: payload,
                    expiresAt: Date().addingTimeInterval(persistentLifetime)
                )
            }
            try FileManager.default.removeItem(at: legacyCacheURL)
            log.info("[DirectorySizeService] migrated \(decoded.count) legacy entries to SQLite")
        } catch {
            log.error("[DirectorySizeService] legacy migration failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Shallow Size (first level only, ~1ms)
    /// Sum file sizes of direct children only — no recursion.
    /// Returns approximate size instantly for UI display with "~" prefix.
    func shallowSize(for url: URL) async -> Int64 {
        guard !Self.cancellation.isCancelled else { return Self.unavailableSize }
        let resolvedURL = resolveURLForSizing(url)
        guard !AppState.isAppManagedNetworkMountPath(resolvedURL) else {
            return Self.unavailableSize
        }
        //log.info("[DirectorySizeService] shallowSize start: \(resolvedURL.path)")
        let result = await withCheckedContinuation { (continuation: CheckedContinuation<Int64, Never>) in
            queue.async { [weak self] in
                guard let self else {
                    continuation.resume(returning: Self.unavailableSize)
                    return
                }
                guard !Self.cancellation.isCancelled else {
                    continuation.resume(returning: Self.unavailableSize)
                    return
                }
                let size: Int64 = self.withSecurityScope(resolvedURL) {
                    DirectorySizeNativeCalculator.shallowSize(resolvedURL)
                }
                continuation.resume(returning: size)
            }
        }
        return result
    }
}
