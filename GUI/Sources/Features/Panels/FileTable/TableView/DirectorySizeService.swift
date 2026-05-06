//
//  DirectorySizeService.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 13.03.2026.
//

import AppKit
import Foundation

/// Calculates directory sizes asynchronously with:
/// - concurrency limit
/// - persistent disk cache
/// - very low CPU usage
///
/// This service is intentionally isolated from UI code.
/// UI requests a size → service returns cached value or calculates it.
actor DirectorySizeService {

    // MARK: - Singleton

    static let shared = DirectorySizeService()
    private nonisolated static let cancellation = DirectorySizeCancellationState()
    // MARK: - Constants
    /// Special value meaning: size could not be determined (permission/sandbox/virtual FS/unreadable).
    /// IMPORTANT: Do not format/display this as a real size.
    static let unavailableSize: Int64 = -1

    // MARK: - Security-Scoped Access

    /// Best-effort wrapper for sandboxed locations.
    /// If the URL is not security-scoped, startAccessingSecurityScopedResource() returns false and we still try.
    nonisolated private func withSecurityScope<T>(_ url: URL, _ work: () throws -> T) rethrows -> T {
        // Best-effort: only attempt security-scoped access for file URLs.
        // If not security-scoped, `startAccessing...` returns false and we still execute `work()`.
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

    /// Disk cache location
    private let cacheURL: URL

    // MARK: - Cache Entry
    private struct CacheEntry: Codable {
        let size: Int64
        let mtime: TimeInterval
    }

    // MARK: - Init
    private init() {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("MiMiNavigator", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        cacheURL = dir.appendingPathComponent("dirsize.cache")
        Task { await self.loadDiskCache() }
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
        let key = cacheKey(for: resolvedURL)
        // fast bail: already known unreadable — don't even try
        if permanentlyUnavailable.contains(key) {
            return Self.unavailableSize
        }
        if let cached = cachedSize(for: resolvedURL) {
            return cached
        }
        if let existingTask = inFlightTask(for: key) {
            return await existingTask.value
        }
        let task = makeSizeTask(for: resolvedURL)
        setInFlightTask(task, for: key)
        let result = await task.value
        clearInFlightTask(for: key)
        // mark as permanently unavailable if unreadable
        if result == Self.unavailableSize {
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

    private func makeSizeTask(for url: URL) -> Task<Int64, Never> {
        Task { [weak self] () -> Int64 in
            guard let self else { return Self.unavailableSize }
            let size = await self.computeSizeOnBackgroundQueue(for: url)
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
        inFlightTasks.removeAll()
        log.info("[DirectorySizeService] shutdown requested")
    }

    private func computeSizeOnBackgroundQueue(for url: URL) async -> Int64 {
        await withCheckedContinuation { (continuation: CheckedContinuation<Int64, Never>) in
            queue.async { [semaphore, weak self] in
                guard let self else {
                    continuation.resume(returning: Self.unavailableSize)
                    return
                }
                semaphore.wait()
                defer { semaphore.signal() }
                guard !Self.cancellation.isCancelled else {
                    continuation.resume(returning: Self.unavailableSize)
                    return
                }
                // Phase 2 + 3 native calculation (security-scoped best-effort)
                let size: Int64 = self.withSecurityScope(url) {
                    DirectorySizeNativeCalculator.directorySize(url, cancellation: Self.cancellation)
                }
                continuation.resume(returning: size)
            }
        }
    }

    // MARK: - Cache Lookup

    private func cachedSize(for url: URL) -> Int64? {
        let path = url.resolvingSymlinksInPath().path
        guard let mtime = fileModificationTime(forResolvedPath: path, urlForScope: url.resolvingSymlinksInPath()) else {
            return nil
        }
        guard let entry = memoryCache[path] else { return nil }
        if entry.size == Self.unavailableSize {
            return nil
        }
        if entry.mtime == mtime {
            return entry.size
        }
        return nil
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
        let entry = CacheEntry(size: size, mtime: mtime)
        memoryCache[path] = entry
        Task.detached(priority: .utility) { [snapshot = memoryCache, cacheURL = cacheURL] in
            if let data = try? JSONEncoder().encode(snapshot) {
                try? data.write(to: cacheURL, options: .atomic)
            }
        }
    }

    // MARK: - Disk Cache

    private func loadDiskCache() async {
        guard let data = try? Data(contentsOf: cacheURL) else { return }
        if let decoded = try? JSONDecoder().decode([String: CacheEntry].self, from: data) {
            memoryCache = decoded
        }
    }

    // MARK: - Shallow Size (first level only, ~1ms)
    /// Sum file sizes of direct children only — no recursion.
    /// Returns approximate size instantly for UI display with "~" prefix.
    func shallowSize(for url: URL) async -> Int64 {
        guard !Self.cancellation.isCancelled else { return Self.unavailableSize }
        let resolvedURL = resolveURLForSizing(url)
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
