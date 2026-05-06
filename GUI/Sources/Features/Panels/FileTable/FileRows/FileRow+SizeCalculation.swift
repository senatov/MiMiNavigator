// FileRow+SizeCalculation.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 23.10.2024.
// Copyright © 2024-2026 Senatov. All rights reserved.
// Description: Directory/symlink size calculation logic extracted from FileRow.
//              Phase 1 (shallow estimate) + Phase 2 (full recursive) + fallback scan.
//              Pure business logic — no SwiftUI Views.

import FileModelKit
import Foundation

// MARK: - Size Calculation Logic
extension FileRow {

    private var isMountedVolumeDirectory: Bool {
        let path = file.urlValue.path
        return path.hasPrefix("/Volumes/") && path != "/Volumes"
    }

    // MARK: - Symlink size calculation
    func runSymlinkSizeTask() async {
        log.info("[FileRow] Task started for symlink file '\(file.nameStr)'")
        if file.sizeCalculationStarted {
            log.info("[FileRow] Skip - already started for symlink '\(file.nameStr)'")
            return
        }
        file.sizeCalculationStarted = true
        let resolved = file.urlValue.resolvingSymlinksInPath()
        if let attrs = try? FileManager.default.attributesOfItem(atPath: resolved.path),
            let fileSize = attrs[.size] as? NSNumber
        {
            file.cachedAppSize = fileSize.int64Value
            file.sizeIsExact = true
            file.sizeCalculationStarted = false
            log.info("[FileRow] Symlink file '\(file.nameStr)' size=\(fileSize.int64Value)")
        }
    }

    // MARK: - Directory size task orchestration
    func runDirectorySizeTask() async {
        let fileURL = file.urlValue
        guard !appState.isTerminating else {
            file.sizeCalculationStarted = false
            return
        }

        if AppState.isRemotePath(fileURL) {
            log.debug("[FileRow] Skipping remote directory size calculation for '\(file.nameStr)' path='\(fileURL.path)'")
            file.cachedDirectorySize = nil
            file.cachedShallowSize = nil
            file.sizeIsExact = false
            file.sizeCalculationStarted = false
            return
        }

        if isMountedVolumeDirectory {
            log.debug("[FileRow] Skipping mounted volume directory size for '\(file.nameStr)' path='\(fileURL.path)'")
            file.cachedDirectorySize = DirectorySizeService.unavailableSize
            file.cachedShallowSize = nil
            file.sizeIsExact = false
            file.sizeCalculationStarted = false
            return
        }

        // Skip known special / virtual directories to avoid useless scans and permission errors
        if shouldSkipSizeCalculation(fileURL) {
            log.debug("[FileRow] Skipping size calculation for special directory '\(file.nameStr)' path='\(fileURL.path)'")
            file.cachedDirectorySize = DirectorySizeService.unavailableSize
            file.sizeIsExact = false
            file.securityState = .restricted
            file.sizeCalculationStarted = false
            return
        }

        if file.cachedDirectorySize == DirectorySizeService.unavailableSize {
            log.debug("[FileRow] Skip - size unavailable already confirmed for '\(file.nameStr)'")
            file.sizeIsExact = false
            file.sizeCalculationStarted = false
            return
        }

        if file.sizeIsExact { return }
        if file.cachedDirectorySize == nil && file.cachedShallowSize == nil {
            file.sizeCalculationStarted = false
        }
        guard !file.sizeCalculationStarted else {
            return
        }
        file.sizeCalculationStarted = true
        let targetURL = resolvedDirectorySizeTargetURL(from: fileURL)
        await withTaskGroup(of: Void.self) { group in
            group.addTask(priority: .utility) {
                await self.performPhase1Shallow(for: targetURL)
            }
            group.addTask(priority: .utility) {
                await self.performPhase2FullSize(for: targetURL)
            }
            for await _ in group {}
        }
        // bump filesVersion so autofit re-triggers with real sizes
        if file.sizeIsExact {
            appState.bumpFilesVersion(for: panelSide)
        }
    }

    // MARK: - Phase 1: shallow directory size (fast estimate)
    private func performPhase1Shallow(for url: URL) async {
        if file.cachedShallowSize != nil { return }
        if file.sizeIsExact { return }
        let timeoutMs: UInt64 = 120
        let shallowOpt = await shallowSizeWithTimeout(url: url, timeoutMs: timeoutMs)
        if Task.isCancelled {
            file.sizeCalculationStarted = false
            return
        }
        guard let shallow = shallowOpt else {
            log.debug("[FileRow] Phase 1 skipped for '\(file.nameStr)' (timeout=\(timeoutMs)ms)")
            return
        }
        if shallow == 0, hasNonZeroChildCountHint() || file.isSymbolicDirectory || isLikelyVirtualDirectory(url) {
            log.debug("[FileRow] Phase 1 produced 0 for '\(file.nameStr)' but looks non-empty — not showing estimate")
            return
        }
        file.cachedShallowSize = shallow
    }

    // MARK: - Phase 2: full recursive directory size
    private func performPhase2FullSize(for url: URL) async {
        let size = await DirectorySizeService.shared.requestSize(for: url)
        if Task.isCancelled {
            file.sizeCalculationStarted = false
            return
        }
        if size == DirectorySizeService.unavailableSize {
            let shouldFallback = hasNonZeroChildCountHint() || file.isSymbolicDirectory || isLikelyVirtualDirectory(url)
            if shouldFallback {
                log.debug("[FileRow] Phase 2 unavailable for '\(file.nameStr)' — running fallback scan")
                let fallback = await fallbackDirectoryScanAsync(url: url)
                file.cachedDirectorySize = fallback
                file.sizeIsExact = fallback > 0
                file.sizeCalculationStarted = false
                log.info("[FileRow] Phase 2 complete (fallback): '\(file.nameStr)' size=\(fallback)")
                return
            } else {
                log.warning("[FileRow] Phase 2 unavailable for '\(file.nameStr)' — marking as restricted (🔒)")

                // Mark as inaccessible instead of pretending size exists
                file.cachedDirectorySize = nil
                file.sizeIsExact = false
                file.securityState = .restricted
                file.sizeCalculationStarted = false

                return
            }
        }
        let finalSize = await resolveZeroSizeIfNeeded(size, url: url)
        if finalSize == 0 {
            let shallow = file.cachedShallowSize ?? 0
            let looksVirtual = file.isSymbolicDirectory || isLikelyVirtualDirectory(url)
            let provenEmpty = isTrulyEmptyDirectory(url)
            let hasChildrenHint = hasNonZeroChildCountHint()
            // Treat system-like folders as suspicious (macOS lies with 0 sometimes)
            let isSystemLike = shouldSkipSizeCalculation(url)
            let shouldFallback = (shallow > 0) || hasChildrenHint || looksVirtual || isSystemLike || !provenEmpty

            if shouldFallback {
                let fallback = await fallbackDirectoryScanAsync(url: url)

                if fallback > 0 {
                    file.cachedDirectorySize = fallback
                    file.sizeIsExact = true
                    file.securityState = .normal
                    log.info("[FileRow] Phase 2 recovered via fallback: '\(file.nameStr)' size=\(fallback)")
                } else if isDirectlyUnreadableDirectory(url) {
                    file.cachedDirectorySize = nil
                    file.sizeIsExact = false
                    file.securityState = .restricted
                    log.warning(
                        "[FileRow] Phase 2 fallback failed for '\(file.nameStr)' and root path is unreadable → marking as restricted (🔒)"
                    )
                } else if file.isSymbolicDirectory || isLikelyVirtualDirectory(url) {
                    file.cachedDirectorySize = DirectorySizeService.unavailableSize
                    file.sizeIsExact = false
                    file.securityState = .normal
                    log.info(
                        "[FileRow] Phase 2 could not determine size for cloud/symlink directory '\(file.nameStr)' — caching size as unavailable"
                    )
                } else {
                    file.cachedDirectorySize = 0
                    file.sizeIsExact = true
                    file.securityState = .normal
                    log.info("[FileRow] Phase 2 confirmed zero size for '\(file.nameStr)' after fallback")
                }

                file.sizeCalculationStarted = false
                return
            }
        }
        file.cachedDirectorySize = finalSize
        file.sizeIsExact = true
        file.securityState = .normal
        file.sizeCalculationStarted = false
        log.info("[FileRow] Phase 2 complete: '\(file.nameStr)' size=\(finalSize)")
    }

    // MARK: - Suspicious zero handler
    private func resolveZeroSizeIfNeeded(_ size: Int64, url: URL) async -> Int64 {
        if size == DirectorySizeService.unavailableSize { return size }
        return size
    }

    // MARK: - Shallow size with timeout
    private func shallowSizeWithTimeout(url: URL, timeoutMs: UInt64) async -> Int64? {
        let target = resolvedDirectorySizeTargetURL(from: url)
        return await withTaskGroup(of: Int64?.self) { group in
            group.addTask(priority: .utility) {
                await DirectorySizeService.shared.shallowSize(for: target)
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: timeoutMs * 1_000_000)
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }

    // MARK: - Fallback directory scan (slow but reliable)
    private func fallbackDirectoryScanAsync(url: URL) async -> Int64 {
        let target = resolvedDirectorySizeTargetURL(from: url)

        return
            await Task.detached(priority: .utility) {
                let fm = FileManager.default
                var total: Int64 = 0
                let keys: Set<URLResourceKey> = [
                    .isDirectoryKey,
                    .fileSizeKey,
                    .fileAllocatedSizeKey,
                    .totalFileAllocatedSizeKey,
                    .isReadableKey,
                ]

                let enumerator = fm.enumerator(
                    at: target,
                    includingPropertiesForKeys: Array(keys),
                    options: [.skipsPackageDescendants, .skipsHiddenFiles],
                    errorHandler: { failedURL, error in
                        log.warning(
                            "[FileRow] Fallback scan skipping inaccessible path '\(failedURL.path)': \(error.localizedDescription)")
                        return true
                    }
                )

                guard let enumerator else {
                    log.warning("[FileRow] Fallback scan could not start for '\(target.path)'")
                    return 0
                }

                while let next = enumerator.nextObject() as? URL {
                    guard let values = try? next.resourceValues(forKeys: keys) else {
                        log.debug("[FileRow] Fallback scan skipping unreadable metadata for '\(next.path)'")
                        continue
                    }

                    if values.isReadable == false {
                        if values.isDirectory == true {
                            enumerator.skipDescendants()
                        }
                        log.debug("[FileRow] Fallback scan skipping unreadable path '\(next.path)'")
                        continue
                    }

                    if let alloc = values.totalFileAllocatedSize {
                        total += Int64(alloc)
                    } else if let alloc = values.fileAllocatedSize {
                        total += Int64(alloc)
                    } else if let size = values.fileSize {
                        total += Int64(size)
                    }
                }

                return total
            }
            .value
    }

    // MARK: - Helpers
    private func normalizedURLForSize(_ url: URL) -> URL {
        url.resolvingSymlinksInPath().standardizedFileURL
    }

    private func resolvedDirectorySizeTargetURL(from rawURL: URL) -> URL {
        let normalized = normalizedURLForSize(rawURL)
        let fileName = trimmedDirectoryDisplayName()

        guard !fileName.isEmpty else {
            return normalized
        }

        if directoryDisplayNameMatchesURL(normalized, fileName: fileName) {
            return normalized
        }

        guard let candidate = appendedDirectoryCandidate(baseURL: normalized, fileName: fileName) else {
            log.debug("[FileRow] sizeTarget fallback '\(file.nameStr)' raw='\(rawURL.path)' normalized='\(normalized.path)'")
            return normalized
        }

        return normalizedURLForSize(candidate)
    }

    private func trimmedDirectoryDisplayName() -> String {
        file.nameStr.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func appendedDirectoryCandidate(baseURL: URL, fileName: String) -> URL? {
        let candidate = baseURL.appendingPathComponent(fileName, isDirectory: true)
        var isDirectory: ObjCBool = false

        guard FileManager.default.fileExists(atPath: candidate.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return nil
        }

        return candidate
    }

    private func directoryDisplayNameMatchesURL(_ url: URL, fileName: String) -> Bool {
        guard !fileName.isEmpty else { return false }
        if url.lastPathComponent == fileName { return true }

        let keys: Set<URLResourceKey> = [.nameKey, .localizedNameKey, .volumeNameKey]
        guard let values = try? url.resourceValues(forKeys: keys) else { return false }

        let candidates = [values.name, values.localizedName, values.volumeName]
        return candidates.contains(fileName)
    }

    // MARK: -
    private func hasNonZeroChildCountHint() -> Bool {
        guard let count = file.childCount else { return false }
        return count > 0
    }

    // MARK: -
    private func isTrulyEmptyDirectory(_ url: URL) -> Bool {
        let target = normalizedURLForSize(url)
        let fm = FileManager.default
        guard
            let enumerator = fm.enumerator(
                at: target, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
                options: [.skipsPackageDescendants]
            )
        else { return false }
        for case let fileURL as URL in enumerator {
            if let vals = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey]),
                vals.isDirectory != true,
                let size = vals.fileSize, size > 0
            {
                return false
            }
        }
        return true
    }

    // MARK: -
    private func isLikelyVirtualDirectory(_ url: URL) -> Bool {
        let p = url.path
        if p.contains("/Library/CloudStorage/") { return true }
        if p.contains("/Library/Mobile Documents/") { return true }
        if p.contains("OneDrive") { return true }
        if p.contains("ProtonDrive") { return true }
        return false
    }

    private func isDirectlyUnreadableDirectory(_ url: URL) -> Bool {
        let target = normalizedURLForSize(url)
        let path = target.path
        return !FileManager.default.isReadableFile(atPath: path)
    }

    // MARK: - Detect directories where size calculation should be skipped (system / virtual / restricted)
    private func shouldSkipSizeCalculation(_ url: URL) -> Bool {
        // Remote URLs (sftp:// ftp://) — FileManager can't resolve, skip immediately
        if AppState.isRemotePath(url) { return true }
        // Remote paths stored as local paths (e.g. "/pub", "/pub/docs") with no host prefix
        // When the panel is showing remote content these paths have no leading real filesystem component
        if let scheme = url.scheme, scheme != "file" { return true }
        let path = url.path
        // macOS restricted or special directories
        if path.hasSuffix("/.Trash") { return true }
        if path.contains("/.Trashes") { return true }
        if path.contains("/Cryptexes") { return true }

        // Mounted volume roots under /Volumes are expensive and pointless to size-scan.
        // Example: /Volumes/Harddisk should open instantly and must not trigger a root-size walk.
        if isMountedVolumeRoot(path) {
            return true
        }

        // Protected / heavy system roots
        let systemRoots: [String] = [
            "/System",
            "/private/var/db",
            "/private/var/run",
            "/private/var/tmp",
            "/private/var/folders",
            "/private/var/protected",
            "/usr/lib",
            "/usr/share",
            "/Volumes/Preboot",
            "/Volumes/VM",
        ]
        for root in systemRoots {
            if path.hasPrefix(root) {
                return true
            }
        }
        return false
    }

    private func isMountedVolumeRoot(_ path: String) -> Bool {
        let normalized = NSString(string: path).standardizingPath
        guard normalized.hasPrefix("/Volumes/"), normalized != "/Volumes" else { return false }
        return normalized.split(separator: "/").count == 2
    }
}
