//
//  DirectorySizeService.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 13.03.2026.
//

import Darwin
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

    // MARK: - Security-Scoped Access

    /// Best-effort wrapper for sandboxed locations.
    /// If the URL is not security-scoped, startAccessingSecurityScopedResource() returns false and we still try.
    nonisolated private func withSecurityScope<T>(_ url: URL, _ work: () throws -> T) rethrows -> T {
        let didStart = url.startAccessingSecurityScopedResource()
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
    }

    // MARK: - Public API
    /// Request directory size.
    /// Returns cached value immediately if available.
    func requestSize(for url: URL) async -> Int64 {
        let resolvedURL = resolveURLForSizing(url)
        let path = cacheKey(for: resolvedURL)

        if let cached = cachedSize(for: resolvedURL) {
            return cached
        }

        if let existingTask = inFlightTask(for: path) {
            return await existingTask.value
        }

        let task = makeSizeTask(for: resolvedURL)
        setInFlightTask(task, for: path)

        let result = await task.value
        clearInFlightTask(for: path)
        return result
    }

    // MARK: - Request helpers

    private func resolveURLForSizing(_ url: URL) -> URL {
        // Resolve symlinks for consistent cache keys and calculation
        url.resolvingSymlinksInPath()
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
            guard let self else { return 0 }

            let size = await self.computeSizeOnBackgroundQueue(for: url)
            await self.storeCache(size: size, for: url)
            return size
        }
    }

    private func computeSizeOnBackgroundQueue(for url: URL) async -> Int64 {
        await withCheckedContinuation { (continuation: CheckedContinuation<Int64, Never>) in
            queue.async { [semaphore, weak self] in
                guard let self else {
                    continuation.resume(returning: Int64(0))
                    return
                }

                semaphore.wait()
                defer { semaphore.signal() }

                // Phase 2 + 3 native calculation (security-scoped best-effort)
                let size: Int64 = self.withSecurityScope(url) {
                    Self.computeDirectorySizeNative(url)
                }

                continuation.resume(returning: size)
            }
        }
    }

    // MARK: - Cache Lookup

    private func cachedSize(for url: URL) -> Int64? {

        let path = url.path

        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
            let mtime = attrs[.modificationDate] as? Date
        else {
            return nil
        }

        guard let entry = memoryCache[path] else { return nil }

        if entry.mtime == mtime.timeIntervalSince1970 {
            return entry.size
        }

        return nil
    }

    // MARK: - Cache Store

    private func storeCache(size: Int64, for url: URL) async {

        let path = url.path

        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
            let mtime = attrs[.modificationDate] as? Date
        else {
            return
        }

        let entry = CacheEntry(size: size, mtime: mtime.timeIntervalSince1970)

        memoryCache[path] = entry

        saveDiskCache()
    }

    // MARK: - Disk Cache

    private func loadDiskCache() async {

        guard let data = try? Data(contentsOf: cacheURL) else { return }

        if let decoded = try? JSONDecoder().decode([String: CacheEntry].self, from: data) {
            memoryCache = decoded
        }
    }

    private func saveDiskCache() {

        let snapshot = memoryCache

        guard let data = try? JSONEncoder().encode(snapshot) else { return }

        try? data.write(to: cacheURL, options: .atomic)
    }

    // MARK: - Shallow Size (first level only, ~1ms)

    /// Sum file sizes of direct children only — no recursion.
    /// Returns approximate size instantly for UI display with "~" prefix.
    func shallowSize(for url: URL) async -> Int64 {
        log.info("[DirectorySizeService] shallowSize start: \(url.path)")
        let result = await withCheckedContinuation { (continuation: CheckedContinuation<Int64, Never>) in
            queue.async { [weak self] in
                guard let self else {
                    continuation.resume(returning: Int64(0))
                    return
                }
                let size: Int64 = self.withSecurityScope(url) {
                    Self.computeShallowSize(url)
                }
                log.info("[DirectorySizeService] shallowSize computed: \(url.path) -> \(size)")
                continuation.resume(returning: size)
            }
        }
        log.info("[DirectorySizeService] shallowSize result: \(url.path) -> \(result)")
        return result
    }

    // MARK: - Native Size Calculation (no Python)

    /// Phase 1 – shallow size (direct children only)
    private static func computeShallowSize(_ url: URL) -> Int64 {
        var total: Int64 = 0

        // Truly shallow: list direct children only.
        // Using enumerator(at:) here would walk the entire subtree (slow + can hit permission walls).
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .fileSizeKey]

        guard
            let children = try? FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: Array(keys),
                options: [.skipsHiddenFiles]
            )
        else {
            return 0
        }

        for child in children {
            guard let values = try? child.resourceValues(forKeys: keys) else { continue }
            guard values.isRegularFile == true else { continue }
            total += Int64(values.fileSize ?? 0)
        }

        return total
    }

    /// Phase 2 – fast disk usage using stat blocks (Finder‑style)
    /// Note: this can legitimately return 0 for empty dirs, but also for protected/virtual dirs.
    private static func computeFastDiskUsage(_ path: String) -> Int64 {

        var total: Int64 = 0

        let fm = FileManager.default

        guard let enumerator = fm.enumerator(atPath: path) else { return 0 }

        while let item = enumerator.nextObject() as? String {
            let fullPath = path + "/" + item

            var statbuf = stat()

            // lstat can fail on protected entries; ignore and continue
            if lstat(fullPath, &statbuf) == 0 {
                // Count only non-directories to avoid double-counting
                if (statbuf.st_mode & S_IFMT) != S_IFDIR {
                    total += Int64(statbuf.st_blocks) * 512
                }
            }
        }

        return total
    }

    /// Phase 3 – full recursive accurate size.
    /// Uses URL-based enumerator with an error handler so protected entries don't abort the scan.
    /// Prefers allocated size (Finder-like) when available.
    private static func computeFullRecursive(_ url: URL) -> Int64 {

        var total: Int64 = 0

        let fm = FileManager.default

        let keys: Set<URLResourceKey> = [
            .isRegularFileKey,
            .isSymbolicLinkKey,
            .fileSizeKey,
            .fileAllocatedSizeKey,
            .totalFileAllocatedSizeKey,
        ]

        guard
            let enumerator = fm.enumerator(
                at: url,
                includingPropertiesForKeys: Array(keys),
                options: [.skipsHiddenFiles, .skipsPackageDescendants],
                errorHandler: { _, _ in
                    // Keep going even if a subtree is protected or disappears.
                    return true
                }
            )
        else {
            return 0
        }

        while let fileURL = enumerator.nextObject() as? URL {
            guard let values = try? fileURL.resourceValues(forKeys: keys) else { continue }

            // Avoid following symlinks (and possible loops). Count the link itself as 0.
            if values.isSymbolicLink == true {
                continue
            }

            guard values.isRegularFile == true else { continue }

            if let allocated = values.totalFileAllocatedSize {
                total += Int64(allocated)
            } else if let allocated = values.fileAllocatedSize {
                total += Int64(allocated)
            } else if let size = values.fileSize {
                total += Int64(size)
            }
        }

        return total
    }

    /// Combined native strategy
    private static func computeDirectorySizeNative(_ url: URL) -> Int64 {

        let path = url.path
        let fm = FileManager.default

        // Phase 2 fast estimation
        let fast = computeFastDiskUsage(path)

        // If Phase 2 returns 0, it might be a real empty dir OR a protected/virtual dir.
        // In that suspicious case, try Phase 3 (URL enumerator) before giving up.
        if fast == 0 {
            // Fast pass may return 0 for:
            // - empty directories
            // - protected / sandboxed locations (stat/enumerator can fail silently)
            // - virtual filesystems
            // So always try the robust URL enumerator; it has an error handler and may still succeed.
            let full = computeFullRecursive(url)
            if full > 0 {
                return full
            }

            // If full is 0, double-check whether the directory is actually empty.
            // If we cannot read it, treat as 0 (unknown/blocked) rather than crashing.
            if let items = try? fm.contentsOfDirectory(atPath: path), items.isEmpty {
                return 0
            }

            // Non-empty but we still got 0: likely blocked/virtual. Keep 0.
            return 0
        }

        // If result is very small, return quickly
        if fast < 1_000_000 {
            return fast
        }

        // Phase 3 accurate calculation
        return computeFullRecursive(url)
    }
}
