    // FileScanner.swift
    // MiMiNavigator
    //
    // Created by Iakov Senatov on 26.05.2025.
    // Copyright © 2025-2026 Senatov. All rights reserved.
    // Description: High-performance directory scanner.
    //   Uses batch-prefetch of URLResourceValues via contentsOfDirectory(includingPropertiesForKeys:)
    //   and passes pre-fetched values directly to CustomFile.init(url:resourceValues:)
    //   to avoid per-file stat() syscalls. Runs off the main thread.

    import FileModelKit
    import Foundation

    // MARK: - File Scanner

    enum FileScanner {

        /// All resource keys needed by CustomFile — fetched once per directory in a single syscall batch.
        private static let prefetchKeys: [URLResourceKey] = [
            .isDirectoryKey,
            .isSymbolicLinkKey,
            .fileSizeKey,
            .totalFileAllocatedSizeKey,
            .contentModificationDateKey,
            .fileSecurityKey,
            .creationDateKey,
            .contentAccessDateKey,
            .addedToDirectoryDateKey,
            .directoryEntryCountKey,
        ]

        private static let prefetchKeySet = Set(prefetchKeys)

        // MARK: - Scan directory contents

        /// Scans a directory and returns an array of CustomFile.
        /// All file metadata is batch-prefetched — no per-file stat() calls.
        /// Safe to call from any thread (no UI access).
        static func scan(url: URL, showHiddenFiles: Bool = false) throws -> [CustomFile] {
            let startTime = CFAbsoluteTimeGetCurrent()
            log.info("[FileScanner] scan START: \(url.path)")

            let fileManager = FileManager.default


            if !fileManager.isReadableFile(atPath: url.path) {
                log.warning("[FileScanner] path not readable, will attempt contentsOfDirectory: \(url.path)")
                // Don't throw — a parent security-scoped bookmark may still grant access.
                // If contentsOfDirectory fails, DualDirectoryScanner handles the fallback.
            }

            // Volume paths need hidden files visible (BSD UF_HIDDEN flag hides backup content)
            let isVolumePath = url.path.hasPrefix("/Volumes/") && url.path != "/Volumes"
            let effectiveShowHidden = showHiddenFiles || isVolumePath
            let options: FileManager.DirectoryEnumerationOptions = effectiveShowHidden ? [] : [.skipsHiddenFiles]

            var isDirectory: ObjCBool = false
            let exists = fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory)

            guard exists else {
                log.error("[FileScanner] path disappeared before scan: \(url.path)")
                throw NSError(
                    domain: NSCocoaErrorDomain,
                    code: NSFileNoSuchFileError,
                    userInfo: [NSLocalizedDescriptionKey: "Path disappeared before scan: \(url.path)"]
                )
            }

            guard isDirectory.boolValue else {
                log.error("[FileScanner] scan() expected directory but received file: \(url.path)")
                throw NSError(
                    domain: NSCocoaErrorDomain,
                    code: NSFileReadUnknownError,
                    userInfo: [NSLocalizedDescriptionKey: "FileScanner.scan() expected directory but received file: \(url.path)"]
                )
            }

            // Single syscall: enumerate directory AND prefetch all resource values
            let contents: [URL]
            do {
                contents = try fileManager.contentsOfDirectory(
                    at: url,
                    includingPropertiesForKeys: prefetchKeys,
                    options: options
                )
            } catch {
                log.error("[FileScanner] contentsOfDirectory FAILED: \(error.localizedDescription)")
                throw error
            }

            // Build CustomFile array using pre-fetched resource values (no extra stat per file)
            var result: [CustomFile] = []
            result.reserveCapacity(contents.count)

            for fileURL in contents {
                let file: CustomFile

                if let rv = try? fileURL.resourceValues(forKeys: prefetchKeySet) {
                    file = CustomFile(url: fileURL, resourceValues: rv)
                } else {
                    // Fallback if resource values unexpectedly fail
                    file = CustomFile(name: fileURL.lastPathComponent, path: fileURL.path)
                }

                // Deferred metadata loading was moved out of scan() to keep this function
                // concurrency-safe under Swift 6 strict checking.
                // scan() now performs only fast, deterministic model creation.
                result.append(file)
            }

            let elapsed = CFAbsoluteTimeGetCurrent() - startTime
            log.info("[FileScanner] scan DONE: \(result.count) items in \(String(format: "%.3f", elapsed))s")
            return result
        }


        /// Incremental directory scan.
        /// Yields files in batches so the UI can display results progressively.
        /// Useful for very large directories (10k+ files) to avoid blocking UI.
        static func scanIncremental(
            url: URL,
            showHiddenFiles: Bool = false,
            batchSize: Int = 200,
            onBatch: ([CustomFile]) -> Void
        ) throws {

            log.info("[FileScanner] incremental scan START: \(url.path)")

            let fileManager = FileManager.default

            let isVolumePath = url.path.hasPrefix("/Volumes/") && url.path != "/Volumes"
            let effectiveShowHidden = showHiddenFiles || isVolumePath
            let options: FileManager.DirectoryEnumerationOptions = effectiveShowHidden ? [] : [.skipsHiddenFiles]

            guard let enumerator = fileManager.enumerator(
                at: url,
                includingPropertiesForKeys: prefetchKeys,
                options: options
            ) else {
                log.error("[FileScanner] incremental enumerator FAILED")
                return
            }

            // Limit parallel metadata warm-up tasks
            let metadataLimiter = DispatchSemaphore(value: 4)

            var batch: [CustomFile] = []
            batch.reserveCapacity(batchSize)

            for case let fileURL as URL in enumerator {
                if Task.isCancelled { break }
                let fileName = fileURL.lastPathComponent

                let file: CustomFile
                if let rv = try? fileURL.resourceValues(forKeys: prefetchKeySet) {
                    file = CustomFile(url: fileURL, resourceValues: rv)
                } else {
                    file = CustomFile(name: fileName, path: fileURL.path)
                }

                // Parallel metadata warm-up (UTType / localized type description).
                // Runs asynchronously so the main scan loop stays fast.
                // This helps icons and type information appear sooner without blocking UI.
                metadataLimiter.wait()
                Task.detached(priority: .utility) {
                    defer { metadataLimiter.signal() }
                    _ = try? fileURL.resourceValues(forKeys: [
                        .typeIdentifierKey,
                        .localizedTypeDescriptionKey
                    ])
                }

                batch.append(file)

                // Prevent recursive traversal – we only want immediate children
                enumerator.skipDescendants()

                if batch.count >= batchSize {
                    // Progressive sort so UI receives partially ordered results
                    batch.sort { (a: CustomFile, b: CustomFile) -> Bool in
                        let an = a.urlValue.lastPathComponent
                        let bn = b.urlValue.lastPathComponent
                        return an.localizedStandardCompare(bn) == .orderedAscending
                    }

                    onBatch(batch)
                    batch.removeAll(keepingCapacity: true)
                }
            }

            if !batch.isEmpty {
                // Sort the final partial batch as well
                batch.sort { (a: CustomFile, b: CustomFile) -> Bool in
                    let an = a.urlValue.lastPathComponent
                    let bn = b.urlValue.lastPathComponent
                    return an.localizedStandardCompare(bn) == .orderedAscending
                }
                onBatch(batch)
            }

            log.info("[FileScanner] incremental scan DONE")
        }

        // MARK: - Deferred metadata helpers

        /// Returns immediate child count for a directory URL.
        /// Uses OS-level directoryEntryCountKey (single VFS call, no enumeration).
        /// Falls back to contentsOfDirectory only if the OS key is unavailable.
        static func directoryChildCount(at url: URL, showHiddenFiles: Bool = false) -> Int {
            // Prefer OS-cached value — no directory enumeration needed
            if let rv = try? url.resourceValues(forKeys: [.directoryEntryCountKey]),
               let count = rv.directoryEntryCount {
                return count
            }
            // Fallback for filesystems that don't support directoryEntryCountKey
            let fm = FileManager()
            let options: FileManager.DirectoryEnumerationOptions = showHiddenFiles ? [] : [.skipsHiddenFiles]
            return (try? fm.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: nil,
                options: options
            ).count) ?? 0
        }

        /// Computes recursive size for an .app bundle or any directory URL.
        /// This pure helper can be executed on a background queue by the caller,
        /// while model mutation stays on the owning side.
        static func directorySize(at url: URL) -> Int64 {
            let fm = FileManager()
            return recursiveSize(url: url, fileManager: fm)
        }

        // MARK: - Recursive byte size of a directory (used for .app bundles)
        private static func recursiveSize(url: URL, fileManager: FileManager) -> Int64 {
            guard
                let enumerator = fileManager.enumerator(
                    at: url,
                    includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
                    options: [.skipsHiddenFiles]
                )
            else { return 0 }
            var total: Int64 = 0
            for case let fileURL as URL in enumerator {
                if let rv = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey]),
                    rv.isDirectory != true,
                    let sz = rv.fileSize
                {
                    total += Int64(sz)
                }
            }
            return total
        }
    }
