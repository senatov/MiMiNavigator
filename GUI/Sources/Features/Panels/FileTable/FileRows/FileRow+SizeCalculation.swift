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
            log.info("[FileRow] Task started for directory '\(file.nameStr)' symDir=\(file.isSymbolicDirectory)")
            // Skip known special / virtual directories to avoid useless scans and permission errors
            if shouldSkipSizeCalculation(file.urlValue) {
                log.debug("[FileRow] Skipping size calculation for special directory '\(file.nameStr)' path='\(file.urlValue.path)'")
                file.cachedAppSize = DirectorySizeService.unavailableSize
                file.sizeIsExact = false
                file.sizeCalculationStarted = false
                return
            }
            if file.sizeIsExact { return }
            if file.cachedAppSize == nil && file.cachedShallowSize == nil {
                file.sizeCalculationStarted = false
            }
            guard !file.sizeCalculationStarted else {
                log.info("[FileRow] Skip - already started for '\(file.nameStr)'")
                return
            }
            file.sizeCalculationStarted = true
            let targetURL = normalizedURLForSize(file.urlValue)
            await withTaskGroup(of: Void.self) { group in
                group.addTask(priority: .utility) { [fileName = file.nameStr] in
                    await self.performPhase1Shallow(for: targetURL)
                    log.verbose("[FileRow] Phase 1 task finished for '\(fileName)'")
                }
                group.addTask(priority: .utility) { [fileName = file.nameStr] in
                    await self.performPhase2FullSize(for: targetURL)
                    log.verbose("[FileRow] Phase 2 task finished for '\(fileName)'")
                }
                for await _ in group {}
            }
        }

        // MARK: - Phase 1: shallow directory size (fast estimate)
        private func performPhase1Shallow(for url: URL) async {
            log.info("[FileRow] Phase 1 (estimate): shallow size for '\(file.nameStr)' url='\(url.path)'")
            if file.cachedShallowSize != nil { return }
            if file.sizeIsExact { return }
            let timeoutMs: UInt64 = 120
            let shallowOpt = await shallowSizeWithTimeout(url: url, timeoutMs: timeoutMs)
            if Task.isCancelled {
                log.info("[FileRow] Phase 1 cancelled for '\(file.nameStr)'")
                file.sizeCalculationStarted = false
                return
            }
            guard let shallow = shallowOpt else {
                log.info("[FileRow] Phase 1 skipped for '\(file.nameStr)' (timeout=\(timeoutMs)ms)")
                return
            }
            if shallow == 0, hasNonZeroChildCountHint() || file.isSymbolicDirectory || isLikelyVirtualDirectory(url) {
                log.info("[FileRow] Phase 1 produced 0 for '\(file.nameStr)' but looks non-empty — not showing estimate")
                return
            }
            file.cachedShallowSize = shallow
            log.info("[FileRow] Phase 1 complete (estimate): '\(file.nameStr)' shallow=\(shallow)")
        }

        // MARK: - Phase 2: full recursive directory size
        private func performPhase2FullSize(for url: URL) async {
            log.info("[FileRow] Phase 2: full size for '\(file.nameStr)' url='\(url.path)'")
            let size = await DirectorySizeService.shared.requestSize(for: url)
            if Task.isCancelled {
                log.info("[FileRow] Phase 2 cancelled for '\(file.nameStr)'")
                file.sizeCalculationStarted = false
                return
            }
            if size == DirectorySizeService.unavailableSize {
                let shouldFallback = hasNonZeroChildCountHint() || file.isSymbolicDirectory || isLikelyVirtualDirectory(url)
                if shouldFallback {
                    log.warning("[FileRow] Phase 2 unavailable for '\(file.nameStr)' — running fallback scan")
                    let fallback = await fallbackDirectoryScanAsync(url: url)
                    file.cachedAppSize = fallback
                    file.sizeIsExact = fallback > 0
                    file.sizeCalculationStarted = false
                    log.info("[FileRow] Phase 2 complete (fallback): '\(file.nameStr)' size=\(fallback)")
                    return
                } else {
                    log.warning("[FileRow] Phase 2 unavailable for '\(file.nameStr)' — keeping non-exact")
                    file.cachedAppSize = DirectorySizeService.unavailableSize
                    file.sizeIsExact = false
                    file.sizeCalculationStarted = false
                    return
                }
            }
            let finalSize = await resolveZeroSizeIfNeeded(size, url: url)
            if finalSize == 0 {
                let looksVirtual = file.isSymbolicDirectory || isLikelyVirtualDirectory(url)
                let provenEmpty = isTrulyEmptyDirectory(url)
                if looksVirtual || !provenEmpty {
                    log.warning("[FileRow] Phase 2 produced 0 for '\(file.nameStr)' — keeping non-exact")
                    file.cachedAppSize = 0
                    file.sizeIsExact = false
                    file.sizeCalculationStarted = false
                    return
                }
            }
            file.cachedAppSize = finalSize
            file.sizeIsExact = true
            file.sizeCalculationStarted = false
            log.info("[FileRow] Phase 2 complete: '\(file.nameStr)' size=\(finalSize)")
        }

        // MARK: - Suspicious zero handler
        private func resolveZeroSizeIfNeeded(_ size: Int64, url: URL) async -> Int64 {
            if size == DirectorySizeService.unavailableSize { return size }
            guard size == 0 else { return size }
            let shallow = file.cachedShallowSize ?? 0
            let shouldFallback = (shallow > 0) || hasNonZeroChildCountHint() || file.isSymbolicDirectory || isLikelyVirtualDirectory(url)
            guard shouldFallback else { return 0 }
            log.warning("[FileRow] Phase2 returned 0 for '\(file.nameStr)' — running fallback scan")
            return await fallbackDirectoryScanAsync(url: url)
        }

        // MARK: - Shallow size with timeout
        private func shallowSizeWithTimeout(url: URL, timeoutMs: UInt64) async -> Int64? {
            let target = normalizedURLForSize(url)
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
            let target = normalizedURLForSize(url)
            return await Task.detached(priority: .utility) {
                let fm = FileManager.default
                var total: Int64 = 0
                let keys: Set<URLResourceKey> = [
                    .isDirectoryKey, .fileSizeKey, .fileAllocatedSizeKey, .totalFileAllocatedSizeKey,
                ]
                if let enumerator = fm.enumerator(
                    at: target, includingPropertiesForKeys: Array(keys),
                    options: [.skipsPackageDescendants]
                ) {
                    while let next = enumerator.nextObject() as? URL {
                        if let values = try? next.resourceValues(forKeys: keys) {
                            if let alloc = values.totalFileAllocatedSize {
                                total += Int64(alloc)
                            } else if let alloc = values.fileAllocatedSize {
                                total += Int64(alloc)
                            } else if let s = values.fileSize {
                                total += Int64(s)
                            }
                        }
                    }
                }
                return total
            }.value
        }

        // MARK: - Helpers
        func normalizedURLForSize(_ url: URL) -> URL {
            url.resolvingSymlinksInPath().standardizedFileURL
        }

        func hasNonZeroChildCountHint() -> Bool {
            let raw = file.childCountFormatted.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !raw.isEmpty, raw != "0", raw != "-" else { return false }
            return true
        }

        func isTrulyEmptyDirectory(_ url: URL) -> Bool {
            let target = normalizedURLForSize(url)
            let fm = FileManager.default
            guard let enumerator = fm.enumerator(
                at: target, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
                options: [.skipsPackageDescendants]
            ) else { return false }
            for case let fileURL as URL in enumerator {
                if let vals = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey]),
                   vals.isDirectory != true,
                   let size = vals.fileSize, size > 0
                { return false }
            }
            return true
        }

        func isLikelyVirtualDirectory(_ url: URL) -> Bool {
            let p = url.path
            if p.contains("/Library/CloudStorage/") { return true }
            if p.contains("/Library/Mobile Documents/") { return true }
            if p.contains("OneDrive") { return true }
            if p.contains("ProtonDrive") { return true }
            return false
        }
        /// Detect directories where size calculation should be skipped (system / virtual / restricted)
        func shouldSkipSizeCalculation(_ url: URL) -> Bool {
            let path = url.path

            // macOS restricted or special directories
            if path.hasSuffix("/.Trash") { return true }
            if path.contains("/.Trashes") { return true }
            if path.contains("/Cryptexes") { return true }

            // Known virtual storage providers
            if path.contains("/Library/CloudStorage/") { return true }
            if path.contains("/Library/Mobile Documents/") { return true }

            // Third‑party cloud drives (can behave like virtual FS)
            if path.contains("OneDrive") { return true }
            if path.contains("ProtonDrive") { return true }

            return false
        }
    }
