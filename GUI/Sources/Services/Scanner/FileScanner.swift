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

        /// Resource keys prefetched in one batch syscall via contentsOfDirectory.
        /// fileSecurityKey        — permissions + owner (kernel VFS-cached, negligible overhead).
        /// directoryEntryCountKey — child count without directory enumeration.
        /// Date keys              — creation, last-access, added-to-directory for extended columns.
        private static let prefetchKeys: [URLResourceKey] = [
            .isDirectoryKey,
            .isSymbolicLinkKey,
            .fileSizeKey,
            .contentModificationDateKey,
            .fileSecurityKey,
            .directoryEntryCountKey,
            .creationDateKey,
            .contentAccessDateKey,
            .addedToDirectoryDateKey,
        ]

        private static let prefetchKeySet = Set(prefetchKeys)

        // MARK: - Scan directory contents

        /// Scans a directory and returns an array of CustomFile.
        /// All file metadata is batch-prefetched — no per-file stat() calls.
        /// Safe to call from any thread (no UI access).
        static func scan(url: URL, showHiddenFiles: Bool = false) throws -> [CustomFile] {
            let startTime = CFAbsoluteTimeGetCurrent()
            log.debug("[FileScanner] scan: \(url.path)")

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

                if let rv = try? fileURL.resourceValues(forKeys: prefetchKeySet),
                   rv.fileSecurity != nil || rv.contentModificationDate != nil
                {
                    // Batch-prefetched resource values are valid — fast path
                    file = CustomFile(url: fileURL, resourceValues: rv)
                } else {
                    // Batch-prefetch returned empty values (common for symlinks into
                    // CloudStorage / File Provider paths and sometimes regular files
                    // on APFS). Fall back to path-based attributesOfItem which always works.
                    file = CustomFile(name: fileURL.lastPathComponent, path: fileURL.path)
                }

                result.append(file)
            }

            let elapsed = CFAbsoluteTimeGetCurrent() - startTime
            log.debug("[FileScanner] scan done: \(result.count) items in \(String(format: "%.3f", elapsed))s")
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

            log.debug("[FileScanner] incremental scan: \(url.path)")

            let fileManager = FileManager.default

            let isVolumePath = url.path.hasPrefix("/Volumes/") && url.path != "/Volumes"
            let effectiveShowHidden = showHiddenFiles || isVolumePath
            let options: FileManager.DirectoryEnumerationOptions = effectiveShowHidden
                ? [.skipsSubdirectoryDescendants, .skipsPackageDescendants]
                : [.skipsHiddenFiles, .skipsSubdirectoryDescendants, .skipsPackageDescendants]

            guard
                let enumerator = fileManager.enumerator(
                    at: url,
                    includingPropertiesForKeys: prefetchKeys,
                    options: options
                )
            else {
                log.error("[FileScanner] incremental enumerator FAILED")
                return
            }

            var batch: [CustomFile] = []
            batch.reserveCapacity(batchSize)

            for case let fileURL as URL in enumerator {
                autoreleasepool {
                    if Task.isCancelled { return }
                    let fileName = fileURL.lastPathComponent

                    let file: CustomFile
                    if let rv = try? fileURL.resourceValues(forKeys: prefetchKeySet),
                       rv.fileSecurity != nil || rv.contentModificationDate != nil
                    {
                        file = CustomFile(url: fileURL, resourceValues: rv)
                    } else {
                        file = CustomFile(name: fileName, path: fileURL.path)
                    }

                    batch.append(file)
                }

                if batch.count >= batchSize {
                    batch.sort { (a: CustomFile, b: CustomFile) -> Bool in
                        a.urlValue.lastPathComponent
                            .localizedStandardCompare(b.urlValue.lastPathComponent) == .orderedAscending
                    }
                    onBatch(batch)
                    batch.removeAll(keepingCapacity: true)
                }
            }

            if !batch.isEmpty {
                batch.sort { (a: CustomFile, b: CustomFile) -> Bool in
                    a.urlValue.lastPathComponent
                        .localizedStandardCompare(b.urlValue.lastPathComponent) == .orderedAscending
                }
                onBatch(batch)
            }

            log.debug("[FileScanner] incremental scan done")
        }

        // MARK: - Deferred metadata helpers

        /// Returns immediate child count for a directory URL.
        /// Uses OS-level directoryEntryCountKey (single VFS call, no enumeration).
        /// Falls back to contentsOfDirectory only if the OS key is unavailable.
        static func directoryChildCount(at url: URL, showHiddenFiles: Bool = false) -> Int {
            if let rv = try? url.resourceValues(forKeys: [.directoryEntryCountKey]),
                let count = rv.directoryEntryCount
            {
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
        /// Pure helper — safe to call on a background queue.
        static func directorySize(at url: URL) -> Int64 {
            return recursiveSize(url: url, fileManager: FileManager())
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
