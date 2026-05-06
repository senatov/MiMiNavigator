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

    /// Full metadata set for local filesystems where batch-prefetch is cheap.
    private static let localPrefetchKeys: [URLResourceKey] = [
        .isDirectoryKey,
        .isSymbolicLinkKey,
        .isAliasFileKey,
        .isPackageKey,
        .isHiddenKey,
        .isReadableKey,
        .isWritableKey,
        .isUserImmutableKey,
        .isSystemImmutableKey,
        .fileSizeKey,
        .contentModificationDateKey,
        .fileSecurityKey,
        .directoryEntryCountKey,
        .creationDateKey,
        .contentAccessDateKey,
        .addedToDirectoryDateKey,
    ]

    /// Lean metadata set for mounted volumes, especially SMB/NAS paths under /Volumes.
    /// Rich keys like security/extra dates can turn a simple listing into many remote round-trips.
    /// Keep directoryEntryCountKey: local external volumes usually return it from filesystem metadata,
    /// and remote filesystems that do not support it simply leave the count empty.
    private static let mountedVolumePrefetchKeys: [URLResourceKey] = [
        .isDirectoryKey,
        .isSymbolicLinkKey,
        .isAliasFileKey,
        .isPackageKey,
        .isHiddenKey,
        .fileSizeKey,
        .contentModificationDateKey,
    ]

    private static let volumesRootPrefetchKeys: [URLResourceKey] = [
        .isDirectoryKey,
        .isSymbolicLinkKey,
        .isAliasFileKey,
        .isHiddenKey,
    ]

    private static let localPrefetchKeySet = Set(localPrefetchKeys)
    private static let mountedVolumePrefetchKeySet = Set(mountedVolumePrefetchKeys)
    private static let volumesRootPrefetchKeySet = Set(volumesRootPrefetchKeys)

    private static let iCloudDriveVisibleContainers: [(containerName: String, displayName: String)] = [
        ("iCloud~is~workflow~my~workflows", "Shortcuts"),
        ("iCloud~com~apple~shortcuts~runtime", "Shortcuts"),
        ("iCloud~com~pixelmatorteam~photo", "Photomator"),
        ("iCloud~com~apple~Playgrounds", "Swift Playground"),
        ("com~apple~Preview", "Preview"),
        ("com~apple~Pages", "Pages"),
        ("com~apple~Numbers", "Numbers"),
    ]

    private static func prefetchConfiguration(for url: URL) -> ([URLResourceKey], Set<URLResourceKey>) {
        if url.path == "/Volumes" {
            return (volumesRootPrefetchKeys, volumesRootPrefetchKeySet)
        }
        let isMountedVolumePath = url.path.hasPrefix("/Volumes/") && url.path != "/Volumes"
        if isMountedVolumePath {
            return (mountedVolumePrefetchKeys, mountedVolumePrefetchKeySet)
        }
        return (localPrefetchKeys, localPrefetchKeySet)
    }

    private static func isICloudDriveRoot(_ url: URL) -> Bool {
        let expected = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs")
            .standardizedFileURL
            .path
        return url.standardizedFileURL.path == expected
    }

    private static func iCloudMobileDocumentsRoot(for cloudDocsURL: URL) -> URL {
        cloudDocsURL
            .deletingLastPathComponent()
            .standardizedFileURL
    }

    private static func finderVisibleICloudContainerEntries(showHiddenFiles: Bool, cloudDocsURL: URL) -> [CustomFile] {
        let mobileDocumentsURL = iCloudMobileDocumentsRoot(for: cloudDocsURL)
        let fileManager = FileManager.default
        let options: FileManager.DirectoryEnumerationOptions = showHiddenFiles ? [] : [.skipsHiddenFiles]

        guard let containers = try? fileManager.contentsOfDirectory(
            at: mobileDocumentsURL,
            includingPropertiesForKeys: [.isDirectoryKey, .isHiddenKey, .contentModificationDateKey],
            options: options
        ) else {
            return []
        }

        let containersByName = Dictionary(
            containers.map { ($0.lastPathComponent, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        var seenNames = Set<String>()
        var entries: [CustomFile] = []

        for visibleContainer in iCloudDriveVisibleContainers {
            guard let containerURL = containersByName[visibleContainer.containerName],
                  seenNames.insert(visibleContainer.displayName).inserted
            else {
                continue
            }

            let documentsURL = containerURL.appendingPathComponent("Documents", isDirectory: true)
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: documentsURL.path, isDirectory: &isDirectory),
                  isDirectory.boolValue
            else {
                continue
            }

            entries.append(CustomFile(name: visibleContainer.displayName, path: documentsURL.path))
        }

        return entries
    }

    private static func mergedICloudDriveRootContents(
        actualContents: [CustomFile],
        showHiddenFiles: Bool,
        cloudDocsURL: URL
    ) -> [CustomFile] {
        guard isICloudDriveRoot(cloudDocsURL) else { return actualContents }

        var seenPaths = Set(actualContents.map(\.pathStr))
        var merged = actualContents

        for entry in finderVisibleICloudContainerEntries(showHiddenFiles: showHiddenFiles, cloudDocsURL: cloudDocsURL) {
            guard seenPaths.insert(entry.pathStr).inserted else { continue }
            merged.append(entry)
        }

        return merged
    }

    // MARK: - Scan directory contents

    /// Scans a directory and returns an array of CustomFile.
    /// All file metadata is batch-prefetched — no per-file stat() calls.
    /// Safe to call from any thread (no UI access).
    static func scan(url: URL, showHiddenFiles: Bool = false) throws -> [CustomFile] {
        let startTime = CFAbsoluteTimeGetCurrent()
        log.debug("[FileScanner] scan: \(url.path)")

        let fileManager = FileManager.default
        let (prefetchKeys, prefetchKeySet) = prefetchConfiguration(for: url)

        // Hard stop for unreadable directories — do not attempt enumeration.
        if !fileManager.isReadableFile(atPath: url.path) {
            log.debug("[FileScanner] unreadable directory skipped: \(url.path)")
            return []
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
            let nsError = error as NSError
            if nsError.code == NSFileReadNoPermissionError {
                log.debug("[FileScanner] permission denied, returning empty: \(url.path)")
                return []
            }
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
                if isVolumePath || url.path == "/Volumes" {
                    file = CustomFile(lightweightURL: fileURL, resourceValues: rv)
                } else {
                    // Batch-prefetched resource values are valid — fast path
                    file = CustomFile(url: fileURL, resourceValues: rv)
                }
            } else if (isVolumePath || url.path == "/Volumes"),
                      let rv = try? fileURL.resourceValues(forKeys: prefetchKeySet)
            {
                file = CustomFile(lightweightURL: fileURL, resourceValues: rv)
            } else {
                // Batch-prefetch returned empty values (common for symlinks into
                // CloudStorage / File Provider paths and sometimes regular files
                // on APFS). Fall back to path-based attributesOfItem which always works.
                file = CustomFile(name: fileURL.lastPathComponent, path: fileURL.path)
            }

            result.append(file)
        }

        result = mergedICloudDriveRootContents(
            actualContents: result,
            showHiddenFiles: showHiddenFiles,
            cloudDocsURL: url
        )
        result.sort(by: groupedNameComparator)
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
        let (prefetchKeys, prefetchKeySet) = prefetchConfiguration(for: url)

        if !fileManager.isReadableFile(atPath: url.path) {
            log.debug("[FileScanner] incremental unreadable skipped: \(url.path)")
            return
        }

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
                batch.sort(by: groupedNameComparator)
                onBatch(batch)
                batch.removeAll(keepingCapacity: true)
            }
        }

        if !batch.isEmpty {
            batch.sort(by: groupedNameComparator)
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
    // MARK: - Stable grouping helpers

    private static func groupedNameComparator(_ lhs: CustomFile, _ rhs: CustomFile) -> Bool {
        let lhsOrder = fileKindOrder(for: lhs.urlValue)
        let rhsOrder = fileKindOrder(for: rhs.urlValue)

        if lhsOrder != rhsOrder {
            return lhsOrder < rhsOrder
        }

        return lhs.urlValue.lastPathComponent
            .localizedStandardCompare(rhs.urlValue.lastPathComponent) == .orderedAscending
    }

    private static func fileKindOrder(for url: URL) -> Int {
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isAliasFileKey, .isPackageKey]
        let rv = try? url.resourceValues(forKeys: keys)

        if rv?.isDirectory == true || rv?.isPackage == true {
            return 0
        }

        if rv?.isAliasFile == true {
            return 2
        }

        return 1
    }
}
