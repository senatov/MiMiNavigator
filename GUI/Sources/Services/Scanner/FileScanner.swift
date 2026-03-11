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
            .contentModificationDateKey,
            .fileSecurityKey,
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
            log.info("[FileScanner] scan START: \(url.path)")

            let fileManager = FileManager.default

            guard fileManager.fileExists(atPath: url.path) else {
                log.error("[FileScanner] path does not exist: \(url.path)")
                throw NSError(
                    domain: NSCocoaErrorDomain,
                    code: NSFileNoSuchFileError,
                    userInfo: [NSLocalizedDescriptionKey: "Path does not exist: \(url.path)"]
                )
            }

            if !fileManager.isReadableFile(atPath: url.path) {
                log.warning("[FileScanner] path not readable, will attempt contentsOfDirectory: \(url.path)")
                // Don't throw — a parent security-scoped bookmark may still grant access.
                // If contentsOfDirectory fails, DualDirectoryScanner handles the fallback.
            }

            // Volume paths need hidden files visible (BSD UF_HIDDEN flag hides backup content)
            let isVolumePath = url.path.hasPrefix("/Volumes/") && url.path != "/Volumes"
            let effectiveShowHidden = showHiddenFiles || isVolumePath
            let options: FileManager.DirectoryEnumerationOptions = effectiveShowHidden ? [] : [.skipsHiddenFiles]

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
                var file: CustomFile
                if let rv = try? fileURL.resourceValues(forKeys: prefetchKeySet) {
                    file = CustomFile(url: fileURL, resourceValues: rv)
                } else {
                    file = CustomFile(name: fileURL.lastPathComponent, path: fileURL.path)
                }
                // Cache child count for directories (one lightweight syscall per dir)
                // Cache child count for directories (one lightweight syscall per dir)
                if file.isDirectory {
                    file.cachedChildCount = (try? fileManager.contentsOfDirectory(
                        at: fileURL,
                        includingPropertiesForKeys: nil,
                        options: []
                    ).count) ?? 0
                }
                if file.isAppBundle {
                    file.cachedAppSize = Self.recursiveSize(url: fileURL, fileManager: fileManager)
                }
                result.append(file)
            }

            let elapsed = CFAbsoluteTimeGetCurrent() - startTime
            log.info("[FileScanner] scan DONE: \(result.count) items in \(String(format: "%.3f", elapsed))s")
            return result
        }

        // MARK: - Recursive byte size of a directory (used for .app bundles)
        private static func recursiveSize(url: URL, fileManager: FileManager) -> Int64 {
            guard let enumerator = fileManager.enumerator(
                at: url,
                includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { return 0 }
            var total: Int64 = 0
            for case let fileURL as URL in enumerator {
                if let rv = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey]),
                   rv.isDirectory != true,
                   let sz = rv.fileSize {
                    total += Int64(sz)
                }
            }
            return total
        }
    }
