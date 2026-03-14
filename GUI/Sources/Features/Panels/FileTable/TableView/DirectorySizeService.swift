    //
    //  DirectorySizeService.swift
    //  MiMiNavigator
    //
    //  Created by Iakov Senatov on 13.03.2026.
    //

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

        // MARK: - Concurrency

        /// Limit simultaneous directory scans
        private let semaphore = DispatchSemaphore(value: 2)

        /// Background queue for directory traversal
        private let queue = DispatchQueue(label: "MiMiNavigator.dirsize",
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

            let path = url.path

            // 1. Return cached result if available
            if let cached = cachedSize(for: url) {
                return cached
            }

            // 2. If a calculation is already running, await it
            if let existingTask = inFlightTasks[path] {
                return await existingTask.value
            }

            // 3. Start a new calculation task
            let task = Task { () -> Int64 in

                let size = await withCheckedContinuation { continuation in
                    queue.async { [semaphore] in
                        semaphore.wait()
                        defer { semaphore.signal() }

                        let size = Self.computeDirectorySize(url)
                        continuation.resume(returning: size)
                    }
                }

                await self.storeCache(size: size, for: url)
                return size
            }

            inFlightTasks[path] = task

            let result = await task.value

            // Remove completed task
            inFlightTasks[path] = nil

            return result
        }

        // MARK: - Cache Lookup

        private func cachedSize(for url: URL) -> Int64? {

            let path = url.path

            guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
                  let mtime = attrs[.modificationDate] as? Date else {
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
                  let mtime = attrs[.modificationDate] as? Date else {
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
            let result = await withCheckedContinuation { continuation in
                queue.async {
                    let size = Self.computeShallowSize(url)
                    log.info("[DirectorySizeService] shallowSize computed: \(url.path) -> \(size)")
                    continuation.resume(returning: size)
                }
            }
            log.info("[DirectorySizeService] shallowSize result: \(url.path) -> \(result)")
            return result
        }

        // MARK: - Shallow Traversal (first level)

        /// Sums allocated sizes of regular files in the immediate directory — no subdirectory descent.
        /// Typically completes in under 1ms even for directories with thousands of entries.
        private static func computeShallowSize(_ url: URL) -> Int64 {
            var total: Int64 = 0
            let keys: Set<URLResourceKey> = [.isRegularFileKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey]
            
            // Resolve symlinks to target directory
            let resolvedURL = url.resolvingSymlinksInPath()
            
            guard let contents = try? FileManager.default.contentsOfDirectory(
                at: resolvedURL, includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles]
            ) else { return 0 }
            for fileURL in contents {
                guard let values = try? fileURL.resourceValues(forKeys: keys) else { continue }
                if values.isRegularFile == true {
                    if let allocated = values.totalFileAllocatedSize {
                        total += Int64(allocated)
                    } else if let allocated = values.fileAllocatedSize {
                        total += Int64(allocated)
                    }
                }
            }
            return total
        }

        // MARK: - Directory Traversal (full recursive)

        /// Recursively calculates directory size.
        private static func computeDirectorySize(_ url: URL) -> Int64 {

            var total: Int64 = 0

            let keys: [URLResourceKey] = [
                .isRegularFileKey,
                .totalFileAllocatedSizeKey,
                .fileAllocatedSizeKey
            ]

            // Resolve symlinks to target directory
            let resolvedURL = url.resolvingSymlinksInPath()

            guard let enumerator = FileManager.default.enumerator(
                at: resolvedURL,
                includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles, .skipsPackageDescendants],
                errorHandler: nil
            ) else {
                return 0
            }

            for case let fileURL as URL in enumerator {

                guard let values = try? fileURL.resourceValues(forKeys: Set(keys)) else { continue }

                // Count only regular files
                if values.isRegularFile == true {

                    if let allocated = values.totalFileAllocatedSize {
                        total += Int64(allocated)
                    } else if let allocated = values.fileAllocatedSize {
                        total += Int64(allocated)
                    }
                }
            }

            return total
        }
    }
