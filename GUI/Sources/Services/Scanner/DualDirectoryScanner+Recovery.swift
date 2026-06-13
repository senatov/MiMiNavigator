// DualDirectoryScanner+Recovery.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 13.06.2026.
// Description: Missing directory recovery, slow scan diagnostics and cache fallback.

import FileModelKit
import Foundation

// MARK: - Scan Recovery Context
struct ScanRecoveryContext {
    let side: FavPanelSide
    let generation: Int
    let showHidden: Bool
    let sortKey: SortKeysEnum
    let sortAsc: Bool
}

// MARK: - Slow Scan Metrics
struct SlowScanMetrics {
    let path: String
    let side: FavPanelSide
    let generation: Int
    let itemCount: Int
    let scanSortDuration: TimeInterval
    let publishDuration: TimeInterval
    let totalDuration: TimeInterval
}

extension DualDirectoryScanner {
    // MARK: - Missing Directory Recovery
    func recoverMissingDirectoryIfNeeded(
        _ url: URL,
        context: ScanRecoveryContext
    ) async -> Bool {
        guard url.isFileURL, !AppState.isExistingDirectory(url.path) else { return false }
        guard let fallbackURL = nearestExistingReadableDirectory(from: url), fallbackURL.path != url.path else {
            return false
        }
        log.warning("[Scan] current directory disappeared side=\(context.side) path='\(url.path)' fallback='\(fallbackURL.path)'")
        await MainActor.run {
            appState.updatePath(fallbackURL, for: context.side)
        }
        startFSEvents(for: context.side, url: fallbackURL)
        do {
            let sorted = try await scanAndSortDirectory(
                at: fallbackURL,
                showHidden: context.showHidden,
                sortKey: context.sortKey,
                sortAsc: context.sortAsc
            )
            guard isCurrentGeneration(context.generation, for: context.side) else { return true }
            lastFullScan[context.side] = Date()
            await DirectoryContentCache.shared.store(
                path: fallbackURL.path,
                files: sorted,
                showHidden: context.showHidden
            )
            await publishSuccessfulScan(sorted, scannedPath: fallbackURL.path, for: context.side)
        } catch {
            log.error("[Scan] fallback scan failed side=\(context.side) path='\(fallbackURL.path)' error=\(error.localizedDescription)")
        }
        return true
    }

    // MARK: - Nearest Existing Readable Directory
    func nearestExistingReadableDirectory(from url: URL) -> URL? {
        var candidate = url.deletingLastPathComponent()
        while candidate.path != "/" {
            if AppState.isReadableDirectory(candidate.path) {
                return candidate
            }
            let parent = candidate.deletingLastPathComponent()
            if parent.path == candidate.path { break }
            candidate = parent
        }
        return AppState.isReadableDirectory("/") ? URL(fileURLWithPath: "/") : nil
    }

    // MARK: - Log Slow Scan
    func logSlowScanIfNeeded(_ metrics: SlowScanMetrics) {
        guard metrics.totalDuration >= 2 || metrics.scanSortDuration >= 2 || metrics.publishDuration >= 1 else {
            return
        }
        let scanSortText = String(format: "%.3f", metrics.scanSortDuration)
        let publishText = String(format: "%.3f", metrics.publishDuration)
        let totalText = String(format: "%.3f", metrics.totalDuration)
        log.warning("[Scan] slow refresh side=\(metrics.side) gen=\(metrics.generation) path='\(metrics.path)' items=\(metrics.itemCount) scanSort=\(scanSortText)s publish=\(publishText)s total=\(totalText)s")
    }

    // MARK: - Cache Fallback on Timeout
    func serveCachedOnTimeout(
        url: URL,
        side: FavPanelSide,
        generation: Int,
        showHidden: Bool
    ) async {
        guard isCurrentGeneration(generation, for: side) else { return }
        if let cached = await DirectoryContentCache.shared.lookup(url.path, showHidden: showHidden) {
            log.info("[Scan] serving \(cached.files.count) cached items after timeout for \(url.path)")
            lastFullScan[side] = Date()
            await publishSuccessfulScan(cached.files, scannedPath: url.path, for: side)
        } else {
            log.warning("[Scan] no cache available after timeout for \(url.path) — panel stays as-is")
        }
    }
}
