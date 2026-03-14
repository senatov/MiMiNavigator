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

            // Resolve symlinks for consistent cache keys and calculation
            let resolvedURL = url.resolvingSymlinksInPath()
            let path = resolvedURL.path

            // 1. Return cached result if available
            if let cached = cachedSize(for: resolvedURL) {
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

                        let size = Self.computeSizeWithPython(url, shallow: false)
                        continuation.resume(returning: size)
                    }
                }

                await self.storeCache(size: size, for: resolvedURL)
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
                    let size = Self.computeSizeWithPython(url, shallow: true)
                    log.info("[DirectorySizeService] shallowSize computed: \(url.path) -> \(size)")
                    continuation.resume(returning: size)
                }
            }
            log.info("[DirectorySizeService] shallowSize result: \(url.path) -> \(result)")
            return result
        }

        // MARK: - Python-based Size Calculation

        /// Calculate directory size using Python script
        /// Handles symlinks, cloud directories (OneDrive, iCloud), and regular directories
        private static func computeSizeWithPython(_ url: URL, shallow: Bool) -> Int64 {
            let mode = shallow ? "shallow" : "full"
            let outputFile = "/tmp/mimi_dirsize_\(UUID().uuidString).json"
            
            // Try multiple possible script paths
            let possiblePaths = [
                // Development path
                "/Users/senat/Develop/MiMiNavigator/GUI/Resources/directory_size.py",
                // Bundle resource path
                Bundle.main.resourcePath.map { "\($0)/directory_size.py" } ?? "",
                // Current directory relative
                "./GUI/Resources/directory_size.py"
            ]
            
            log.info("[DirectorySizeService] Bundle resource path: \(Bundle.main.resourcePath ?? "nil")")
            
            var scriptPath: String?
            for path in possiblePaths {
                if !path.isEmpty && FileManager.default.fileExists(atPath: path) {
                    scriptPath = path
                    log.info("[DirectorySizeService] Found Python script at: \(path)")
                    break
                }
            }
            
            guard let finalScriptPath = scriptPath else {
                log.warning("[DirectorySizeService] Python script not found in any location:")
                for path in possiblePaths {
                    log.warning("[DirectorySizeService]   Tried: \(path) - exists: \(FileManager.default.fileExists(atPath: path))")
                }
                return 0
            }
            
            log.info("[DirectorySizeService] computeSizeWithPython start: \(url.path) mode=\(mode)")
            log.info("[DirectorySizeService] Python command: /usr/bin/python3 \(finalScriptPath) '\(url.path)' \(mode) \(outputFile)")
            
            // Execute Python script
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
            process.arguments = [finalScriptPath, url.path, mode, outputFile]
            
            do {
                try process.run()
                process.waitUntilExit()
                
                let exitCode = process.terminationStatus
                log.info("[DirectorySizeService] Python process finished with exit code: \(exitCode)")
                
                // Check if output file exists
                let fileExists = FileManager.default.fileExists(atPath: outputFile)
                log.info("[DirectorySizeService] Output file exists: \(fileExists) at \(outputFile)")
                
                // Read JSON result
                guard let data = try? Data(contentsOf: URL(fileURLWithPath: outputFile)) else {
                    log.warning("[DirectorySizeService] failed to read data from \(outputFile)")
                    return 0
                }
                
                log.info("[DirectorySizeService] Read \(data.count) bytes from \(outputFile)")
                
                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    log.warning("[DirectorySizeService] failed to parse JSON from \(outputFile)")
                    if let jsonString = String(data: data, encoding: .utf8) {
                        log.warning("[DirectorySizeService] Raw JSON: \(jsonString)")
                    }
                    return 0
                }
                
                // Clean up temp file
                try? FileManager.default.removeItem(atPath: outputFile)
                
                // Parse result
                if let error = json["error"] as? String, !error.isEmpty {
                    log.warning("[DirectorySizeService] Python error: \(error)")
                    return 0
                }
                
                let size = (json["size"] as? NSNumber)?.int64Value ?? 0
                let files = (json["files"] as? NSNumber)?.intValue ?? 0
                
                log.info("[DirectorySizeService] computeSizeWithPython result: \(url.path) -> \(files) files, \(size) bytes")
                return size
                
            } catch {
                log.warning("[DirectorySizeService] Python execution failed: \(error)")
                // Clean up temp file
                try? FileManager.default.removeItem(atPath: outputFile)
                return 0
            }
        }
    }
