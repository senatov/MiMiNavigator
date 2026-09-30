// FileOpsEngine+Delete.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 14.05.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Delete implementation.

import Foundation

// MARK: - Delete Implementation

extension FileOpsEngine {
    static let bulkDeleteThreshold = 512
    private static let recycleBatchSize = 512

    func performDelete(items: [URL]) async throws -> FileOpProgress {
        let isBulkDelete = items.count >= Self.bulkDeleteThreshold
        let totalSize = isBulkDelete ? 0 : calculateTotalSize(items: items)
        let progress = FileOpProgress(totalFiles: items.count, totalBytes: totalSize, type: .delete, destination: nil)
        if isBulkDelete {
            showPanel(progress: progress, itemCount: items.count, operation: "items to Trash")
            progress.updateStatusOnly("Preparing batches for Trash…")
            await Task.yield()
        }
        defer { progress.complete() }
        if isBulkDelete && items.allSatisfy({ canRecycleInBatch($0) }) {
            await recycleBatches(items, progress: progress)
            return progress
        }
        for url in items {
            guard !progress.isCancelled else { break }
            await trashItem(url: url, progress: progress)
        }
        return progress
    }

    // MARK: - Batch Recycling
    private func recycleBatches(_ items: [URL], progress: FileOpProgress) async {
        for start in stride(from: 0, to: items.count, by: Self.recycleBatchSize) {
            guard !progress.isCancelled else { break }
            let end = min(start + Self.recycleBatchSize, items.count)
            let batch = Array(items[start..<end])
            progress.updateStatusOnly("Moving \(start + 1)–\(end) of \(items.count) to Trash…")
            do {
                let recycled = try await FileRecycleService.recycle(batch)
                await recordBatchResult(batch, recycled: recycled, progress: progress)
            } catch {
                log.warning("[FileOpsEngine] batch recycle failed at \(start + 1)–\(end): \(error.localizedDescription); retrying remaining items individually")
                await recordBatchResult(batch, recycled: [:], progress: progress)
            }
        }
    }

    private func recordBatchResult(_ batch: [URL], recycled: [URL: URL], progress: FileOpProgress) async {
        var completed = 0
        for url in batch {
            if recycled[url] != nil || !fm.fileExists(atPath: url.path) {
                completed += 1
            } else if !progress.isCancelled {
                await trashItem(url: url, progress: progress)
            }
        }
        if completed > 0 { progress.batchCompleted(count: completed) }
    }

    private func canRecycleInBatch(_ url: URL) -> Bool {
        !AppLogger.isProtectedLogFile(url)
            && !AppState.isAppManagedNetworkMountPath(url)
            && !url.path.contains("/Library/CloudStorage/")
            && !url.path.contains("/Library/Mobile Documents/")
    }

    func trashItem(url: URL, progress: FileOpProgress) async {
        progress.setCurrentFile(url.lastPathComponent)
        if AppLogger.isProtectedLogFile(url) {
            recordFailure(
                FileOperationDiagnostics.makeProtectedDelete(source: url),
                progress: progress
            )
            return
        }
        if AppState.isAppManagedNetworkMountPath(url),
           let mountPointURL = AppState.appManagedMountPointURL(for: url),
           !SMBFileProvider.isMounted(at: mountPointURL)
        {
            let error = NSError(
                domain: NSCocoaErrorDomain,
                code: NSFileWriteUnknownError,
                userInfo: [NSLocalizedDescriptionKey: "Network mount is disconnected: \(mountPointURL.path)"]
            )
            recordFailure(
                FileOperationDiagnostics.makeDelete(source: url, error: error),
                progress: progress
            )
            return
        }
        let itemSize = fileSize(url: url)
        let isAppManagedItem = AppState.isAppManagedNetworkMountPath(url)
        let result = isAppManagedItem
            ? await deleteAppManagedItem(url: url, progress: progress).map { nil }
            : await recycleItem(url)
        switch result {
        case .success(let trashedURL):
            progress.fileCompleted(name: url.lastPathComponent, success: true)
            if let trashedURL {
                progress.recordCompletedTransfer(from: url, to: trashedURL)
            }
            progress.add(bytes: itemSize)
        case .failure(let error):
            recordFailure(
                FileOperationDiagnostics.makeDelete(source: url, error: error),
                progress: progress
            )
        }
    }

    private func deleteAppManagedItem(url: URL, progress: FileOpProgress) async -> Result<Void, Error> {
        progress.updateStatusOnly("Preparing delete: \(url.lastPathComponent)")
        let isDirectory = isDirectory(url: url)
        guard isDirectory else {
            progress.updateStatusOnly("Deleting file: \(url.lastPathComponent)")
            return await Self.removeItemOffMainActor(url)
        }
        progress.updateStatusOnly("Deleting directory: \(url.lastPathComponent)")
        return await Self.removeItemOffMainActor(url)
    }

    private nonisolated static func removeItemOffMainActor(_ url: URL) async -> Result<Void, Error> {
        await Task.detached(priority: .userInitiated) {
            do {
                try FileManager.default.removeItem(at: url)
                return .success(())
            } catch {
                return .failure(error)
            }
        }.value
    }

    private func recycleItem(_ url: URL) async -> Result<URL?, Error> {
        do {
            return .success(try await FileRecycleService.recycle(url))
        } catch {
            return .failure(error)
        }
    }
}
