//
//  DirectorySizeService.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 13.03.2026.
//

import AppKit
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
                    Self.computeDirectorySizeNative(url)
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
                    Self.computeShallowSize(resolvedURL)
                }
                continuation.resume(returning: size)
            }
        }
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
                options: []
            )
        else {
            return DirectorySizeService.unavailableSize
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

        // Skip unreadable directories early
        if !FileManager.default.isReadableFile(atPath: path) {
            log.debug("[DirectorySizeService] fastDiskUsage skipped unreadable: \(path)")
            return DirectorySizeService.unavailableSize
        }

        var total: Int64 = 0
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(atPath: path) else { return DirectorySizeService.unavailableSize }
        while let item = enumerator.nextObject() as? String {
            if cancellation.isCancelled {
                log.debug("[DirectorySizeService] fastDiskUsage cancelled: \(path)")
                return DirectorySizeService.unavailableSize
            }
            let fullPath = path + "/" + item
            var statbuf = stat()
            // lstat can fail on protected entries; ignore and continue
            if lstat(fullPath, &statbuf) != 0 {
                continue
            }
            let type = statbuf.st_mode & S_IFMT

            // Count only non-directories to avoid double-counting.
            // Also skip symlinks to avoid loops / virtual mounts.
            if type != S_IFDIR && type != S_IFLNK {
                total += Int64(statbuf.st_blocks) * 512
            }
        }
        return total
    }

    /// Phase 3 – full recursive accurate size.
    /// Uses URL-based enumerator with an error handler so protected entries don't abort the scan.
    /// Prefers allocated size (Finder-like) when available.
    private static func computeFullRecursive(_ url: URL) -> Int64 {

        // Skip unreadable directories early
        if !FileManager.default.isReadableFile(atPath: url.path) {
            log.debug("[DirectorySizeService] fullRecursive skipped unreadable: \(url.path)")
            return DirectorySizeService.unavailableSize
        }

        var total: Int64 = 0
        let fm = FileManager.default
        let keys: Set<URLResourceKey> = [
            .isRegularFileKey,
            .isDirectoryKey,
            .isSymbolicLinkKey,
            .fileSizeKey,
            .fileAllocatedSizeKey,
            .totalFileAllocatedSizeKey,
        ]

        guard
            let enumerator = fm.enumerator(
                at: url,
                includingPropertiesForKeys: Array(keys),
                // IMPORTANT: do NOT skip packages here.
                // If you do, folders like /Applications become “0 B”.
                options: [],
                errorHandler: { fileURL, error in
                    // Ignore permission errors to prevent log spam
                    if (error as NSError).code != NSFileReadNoPermissionError {
                        log.warning("[DirectorySizeService] enumerate error: \(fileURL.path) error=\(error.localizedDescription)")
                    }
                    return true
                }
            )
        else {
            return DirectorySizeService.unavailableSize
        }

        var countedFiles = 0
        var skippedSymlinks = 0
        var skippedDirs = 0
        var resourceValueFailures = 0
        var statFallbacks = 0

        while let fileURL = enumerator.nextObject() as? URL {
            if cancellation.isCancelled {
                log.debug("[DirectorySizeService] fullRecursive cancelled: \(url.path)")
                return DirectorySizeService.unavailableSize
            }

            // 1) Prefer resource values (fast + Finder-like).
            if let values = try? fileURL.resourceValues(forKeys: keys) {
                if values.isSymbolicLink == true {
                    skippedSymlinks += 1
                    continue
                }
                if values.isDirectory == true {
                    skippedDirs += 1
                    continue
                }
                guard values.isRegularFile == true else {
                    continue
                }
                if let allocated = values.totalFileAllocatedSize {
                    total += Int64(allocated)
                } else if let allocated = values.fileAllocatedSize {
                    total += Int64(allocated)
                } else if let size = values.fileSize {
                    total += Int64(size)
                } else {
                    // Rare: fall back to stat.
                    if let statSize = statAllocatedSize(path: fileURL.path) {
                        statFallbacks += 1
                        total += statSize
                    }
                }
                countedFiles += 1
                continue
            }
            // 2) If resource values fail (common under sandbox/virtual FS), fall back to lstat.
            resourceValueFailures += 1

            if let statSize = statAllocatedSize(path: fileURL.path) {
                statFallbacks += 1
                total += statSize
                countedFiles += 1
            }
        }
        log.debug(
            "[DirectorySizeService] fullRecursive done: \(url.path) total=\(total) files=\(countedFiles) skippedDirs=\(skippedDirs) skippedSymlinks=\(skippedSymlinks) rvFail=\(resourceValueFailures) statFallbacks=\(statFallbacks)"
        )

        return total
    }

    /// Best-effort allocated size via lstat (st_blocks * 512). Returns nil if lstat fails or the path is a directory/symlink.
    private static func statAllocatedSize(path: String) -> Int64? {
        var statbuf = stat()
        if lstat(path, &statbuf) != 0 {
            return nil
        }

        let type = statbuf.st_mode & S_IFMT

        // Skip directories and symlinks.
        if type == S_IFDIR || type == S_IFLNK {
            return nil
        }

        return Int64(statbuf.st_blocks) * 512
    }

    /// Combined native strategy
    private static func computeDirectorySizeNative(_ url: URL) -> Int64 {

        // Hard stop for unreadable directories
        if !FileManager.default.isReadableFile(atPath: url.path) {
            log.debug("[DirectorySizeService] skipping unreadable directory: \(url.path)")
            return DirectorySizeService.unavailableSize
        }

        let path = url.path
        // Phase 2 fast estimation
        let fast = computeFastDiskUsage(path)
        if fast == DirectorySizeService.unavailableSize {
            log.debug("[DirectorySizeService] Phase2 fast usage unavailable for: \(path)")
            return DirectorySizeService.unavailableSize
        }
        // Fast path: return small results immediately
        if fast > 0, fast < 1_000_000 {
            return fast
        }
        // Suspicious zero: empty OR blocked OR virtual
        if fast == 0 {
            let full = computeFullRecursive(url)
            if full == DirectorySizeService.unavailableSize {
                log.debug("[DirectorySizeService] Phase3 full recursive unavailable for: \(path)")
                return DirectorySizeService.unavailableSize
            }
            if full > 0 {
                log.debug("[DirectorySizeService] Phase3 full recursive produced non-zero result for: \(path)")
                return full
            }
            // If we can confirm it is empty, return 0.
            if isDirectoryEmpty(path: path) == true {
                return 0
            }
            // If unreadable, propagate "unavailable".
            if isDirectoryEmpty(path: path) == nil {
                log.warning("[DirectorySizeService] Directory unreadable, size unavailable: \(path)")
                return DirectorySizeService.unavailableSize
            }
            // Readable but still 0 after full scan: treat as empty.
            log.debug("[DirectorySizeService] Directory readable but size remained 0 after full scan: \(path)")
            return 0
        }

        // Large directory: go accurate
        return computeFullRecursive(url)
    }

    // MARK: - Native sizing helpers
    /// Returns true if the directory is readable and empty, false if readable and non-empty, nil if unreadable.
    private static func isDirectoryEmpty(path: String) -> Bool? {
        do {
            let items = try FileManager.default.contentsOfDirectory(atPath: path)
            return items.isEmpty
        } catch {
            log.debug(
                "[DirectorySizeService] Cannot read directory to verify emptiness: \(path) error=\(error.localizedDescription)")
            return nil
        }
    }
}
