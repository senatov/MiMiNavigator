//  DirectorySizeService.swift
//  MiMiNavigator
//  Created by Iakov Senatov on 13.03.2026.

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
    var memoryCache: [String: CacheEntry] = [:]
    /// Paths unavailable until their filesystem context is invalidated.
    var permanentlyUnavailable: Set<String> = []
    var budgetExceededPaths: Set<String> = []

    /// Tracks directory size calculations currently in progress
    /// Prevents the same directory from being scanned multiple times simultaneously.
    var inFlightTasks: [String: Task<DirectorySizeScanResult, Never>] = [:]
    var inFlightCancellation: [String: DirectorySizeCancellationState] = [:]

    let persistentCache = ApplicationPersistentCache.shared
    private let legacyCacheURL: URL
    let cacheNamespace = "directory-size-v2"
    private let cacheEntryLimit = 64
    private let cacheMaxIdleAge: TimeInterval = 30 * 60
    private let persistentLifetime: TimeInterval = 7 * 24 * 60 * 60

    // MARK: - Cache Entry
    struct CacheEntry: Codable {
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
        budgetExceededPaths.subtract(deadPaths)
        deadCache.forEach { memoryCache.removeValue(forKey: $0) }
        if !deadPaths.isEmpty || !deadCache.isEmpty {
            log.info("\(#function) vol mounted — purged \(deadPaths.count) unavail + \(deadCache.count) cache entries")
        }
    }

    // MARK: - Public API
    /// Request directory size.
    /// Returns cached value immediately if available.
    func requestSize(for url: URL) async -> Int64 {
        await requestSizeResult(for: url).size
    }

    // MARK: - Request With Outcome
    func requestSizeResult(for url: URL) async -> DirectorySizeScanResult {
        guard !Self.cancellation.isCancelled else { return .cancelled }
        let resolvedURL = resolveURLForSizing(url)
        guard !Self.isExpensiveAutomaticRoot(resolvedURL) else {
            log.info("[DirectorySizeService] automatic scan skipped for expensive root: \(resolvedURL.path)")
            return .unavailable
        }
        guard !AppState.isAppManagedNetworkMountPath(resolvedURL) else {
            return .unavailable
        }
        let key = cacheKey(for: resolvedURL)
        if permanentlyUnavailable.contains(key) {
            return budgetExceededPaths.contains(key) ? .budgetExceeded : .unavailable
        }
        if let cached = await cachedSize(for: resolvedURL) {
            return .exact(cached)
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
        if !cancellation.isCancelled {
            switch result {
            case .unavailable, .budgetExceeded:
                permanentlyUnavailable.insert(key)
                if result.isBudgetExceeded { budgetExceededPaths.insert(key) }
                log.info("[DirectorySizeService] automatic result status=\(result.status) path='\(key)'; suppressing repeat scan until invalidation")
            case .exact, .cancelled:
                break
            }
        }
        return result
    }

    // MARK: - Request helpers
    func resolveURLForSizing(_ url: URL) -> URL {
        // Resolve symlinks for consistent cache keys and calculation
        return url.resolvingSymlinksInPath()
    }
    // MARK: - File Attribute Helper
    func fileModificationTime(forResolvedPath path: String, urlForScope: URL) -> TimeInterval? {
        let attrs: [FileAttributeKey: Any]?
        attrs = try? DirectorySizeSecurityScope.access(urlForScope) {
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

    private func inFlightTask(for path: String) -> Task<DirectorySizeScanResult, Never>? {
        inFlightTasks[path]
    }

    private func setInFlightTask(_ task: Task<DirectorySizeScanResult, Never>, for path: String) {
        inFlightTasks[path] = task
    }

    private func clearInFlightTask(for path: String) {
        inFlightTasks[path] = nil
    }

    private func makeSizeTask(for url: URL, cancellation: DirectorySizeCancellationState) -> Task<DirectorySizeScanResult, Never> {
        Task { [weak self] () -> DirectorySizeScanResult in
            guard let self else { return .cancelled }
            let result = await self.computeSizeOnBackgroundQueue(for: url, cancellation: cancellation)
            await self.storeCache(size: result.size, for: url)
            return result
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
        budgetExceededPaths.formIntersection(permanentlyUnavailable)
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

    // MARK: - Release Memory Cache
    func releaseMemoryCache() {
        let released = memoryCache.count
        memoryCache.removeAll(keepingCapacity: false)
        if released > 0 {
            log.info("[DirectorySizeService] released \(released) in-memory entries; persistent SQLite cache retained")
        }
    }

    private func computeSizeOnBackgroundQueue(
        for url: URL,
        cancellation: DirectorySizeCancellationState
    ) async -> DirectorySizeScanResult {
        await withCheckedContinuation { (continuation: CheckedContinuation<DirectorySizeScanResult, Never>) in
            queue.async { [semaphore] in
                let activity = DiagnosticActivity.shared.begin("size:\(url.lastPathComponent)")
                semaphore.wait()
                defer { semaphore.signal() }
                guard !Self.cancellation.isCancelled, !cancellation.isCancelled else {
                    DiagnosticActivity.shared.end(activity, outcome: "cancelled")
                    continuation.resume(returning: .cancelled)
                    return
                }
                let result: DirectorySizeScanResult = DirectorySizeSecurityScope.access(url) {
                    DirectorySizeNativeCalculator.directorySize(url, cancellation: cancellation)
                }
                DiagnosticActivity.shared.end(activity, outcome: result.status)
                continuation.resume(returning: result)
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
        log.debug("[DirectorySizeService] persistent hit path='\(url.lastPathComponent)'")
        return entry.size
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
        trimMemoryCacheIfNeeded()
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

    private func trimMemoryCacheIfNeeded() {
        guard memoryCache.count > cacheEntryLimit else { return }
        let overflow = memoryCache.count - cacheEntryLimit
        let oldestKeys = memoryCache.sorted {
            ($0.value.lastAccess ?? $0.value.mtime) < ($1.value.lastAccess ?? $1.value.mtime)
        }.prefix(overflow).map(\.key)
        for key in oldestKeys { memoryCache[key] = nil }
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
    func shallowSize(for url: URL, timeoutMilliseconds: UInt64) async -> Int64? {
        guard !Self.cancellation.isCancelled else { return Self.unavailableSize }
        let resolvedURL = resolveURLForSizing(url)
        guard !AppState.isAppManagedNetworkMountPath(resolvedURL) else {
            return Self.unavailableSize
        }
        let result = await withCheckedContinuation { (continuation: CheckedContinuation<Int64?, Never>) in
            let gate = ShallowSizeResultGate(continuation: continuation)
            queue.async {
                guard !Self.cancellation.isCancelled else {
                    gate.resolve(Self.unavailableSize)
                    return
                }
                let size: Int64 = DirectorySizeSecurityScope.access(resolvedURL) {
                    DirectorySizeNativeCalculator.shallowSize(resolvedURL)
                }
                gate.resolve(size)
            }
            DispatchQueue.global(qos: .utility).asyncAfter(
                deadline: .now() + .milliseconds(Int(timeoutMilliseconds))
            ) {
                gate.resolve(nil)
            }
        }
        return result
    }
}
