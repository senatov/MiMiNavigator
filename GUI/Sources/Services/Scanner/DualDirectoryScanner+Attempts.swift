// DualDirectoryScanner+Attempts.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 13.06.2026.
// Description: Local scan attempts, preview publishing and scan result diagnostics.

import FileModelKit
import Foundation

extension DualDirectoryScanner {
    // MARK: - Perform Local Scan Attempts
    func performLocalScanAttempts(
        _ urls: [URL],
        originalURL: URL,
        context: ScanAttemptContext
    ) async {
        for (index, url) in urls.enumerated() where validateDirectoryURL(url) {
            log.info("[Scan] attempt \(index + 1)/\(urls.count): \(url.path)")
            let result = await performScanAttempt(
                at: url,
                attemptNumber: index + 1,
                context: context
            )
            if result == .stop { return }
        }
        let durationText = String(format: "%.3f", Date().timeIntervalSince(context.scanStart))
        log.debug("[Scan] finished without access side=\(context.side) path='\(originalURL.path)' gen=\(context.generation) in \(durationText)s")
    }

    // MARK: - Perform Scan Attempt
    private func performScanAttempt(
        at url: URL,
        attemptNumber: Int,
        context: ScanAttemptContext
    ) async -> ScanAttemptResult {
        do {
            let attemptStart = Date()
            let sorted = try await scanAndSortDirectory(
                at: url,
                showHidden: context.showHidden,
                sortKey: context.sortKey,
                sortAsc: context.sortAsc
            )
            let scanDuration = Date().timeIntervalSince(attemptStart)
            guard isCurrentGeneration(context.generation, for: context.side) else {
                logStaleScan(context, phase: "scan")
                return .stop
            }
            await publishPreviewIfNeeded(sorted, context: context)
            guard isCurrentGeneration(context.generation, for: context.side) else {
                logStaleScan(context, phase: "preview")
                return .stop
            }
            guard await MainActor.run(body: { !appState.isTerminating }) else {
                log.info("[Scan] publish skipped: app is terminating for \(context.side)")
                return .stop
            }
            await publishScanResult(sorted, url: url, scanDuration: scanDuration, context: context)
            return .stop
        } catch let error as ScanTimeoutError {
            log.warning("[Scan] \(error.localizedDescription); trying cache fallback")
            await serveCachedOnTimeout(
                url: url,
                side: context.side,
                generation: context.generation,
                showHidden: context.showHidden
            )
            return .stop
        } catch let error as NSError {
            if isPermissionDeniedError(error) {
                log.debug("[Scan] permission denied; trying bookmark recovery for \(url.path)")
                _ = await requestAndRetryAccess(for: url, side: context.side)
                return .stop
            }
            log.error("[Scan] attempt \(attemptNumber) failed: \(error.localizedDescription)")
            return .continueScanning
        }
    }

    // MARK: - Publish Preview
    private func publishPreviewIfNeeded(
        _ files: [CustomFile],
        context: ScanAttemptContext
    ) async {
        guard files.count > progressivePreviewThreshold else { return }
        let preview = Array(files.prefix(progressivePreviewThreshold))
        await MainActor.run {
            AutoFitScheduler.shared.runInitialPublishFit(panel: context.side, files: preview)
            applyPreviewFiles(preview, for: context.side)
        }
    }

    // MARK: - Publish Scan Result
    private func publishScanResult(
        _ files: [CustomFile],
        url: URL,
        scanDuration: TimeInterval,
        context: ScanAttemptContext
    ) async {
        let totalDuration = Date().timeIntervalSince(context.scanStart)
        let scanText = String(format: "%.3f", scanDuration)
        let totalText = String(format: "%.3f", totalDuration)
        log.info("[Scan] succeeded path='\(url.path)' items=\(files.count) scan=\(scanText)s total=\(totalText)s")
        let publishStart = Date()
        lastFullScan[context.side] = Date()
        lastScanDuration[context.side] = scanDuration
        await DirectoryContentCache.shared.store(path: url.path, files: files, showHidden: context.showHidden)
        await publishSuccessfulScan(files, scannedPath: url.path, for: context.side)
        logSlowScanIfNeeded(SlowScanMetrics(
            path: url.path,
            side: context.side,
            generation: context.generation,
            itemCount: files.count,
            scanSortDuration: scanDuration,
            publishDuration: Date().timeIntervalSince(publishStart),
            totalDuration: Date().timeIntervalSince(context.scanStart)
        ))
    }

    // MARK: - Log Stale Scan
    private func logStaleScan(_ context: ScanAttemptContext, phase: String) {
        let currentGeneration = scanGeneration[context.side] ?? -1
        log.debug("[Scan] stale \(phase) result side=\(context.side) gen=\(context.generation) current=\(currentGeneration)")
    }

    // MARK: - Scan and Sort Directory
    func scanAndSortDirectory(
        at url: URL,
        showHidden: Bool,
        sortKey: SortKeysEnum,
        sortAsc: Bool
    ) async throws -> [CustomFile] {
        let scanTask = Task.detached(priority: .userInitiated) {
            let scanned = try FileScanner.scan(url: url, showHiddenFiles: showHidden)
            return FileSortingService.sort(scanned, by: sortKey, bDirection: sortAsc)
        }
        let timeout = effectiveTimeout(for: url)
        return try await scanWithTimeout(scanTask, url: url, timeout: timeout)
    }
}
