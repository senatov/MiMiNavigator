// FileOpsEngine+Delete.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 14.05.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Delete implementation.

import Foundation

// MARK: - Delete Implementation

extension FileOpsEngine {

    func performDelete(items: [URL]) async throws -> FileOpProgress {
        let totalSize = calculateTotalSize(items: items)
        let progress = FileOpProgress(totalFiles: items.count, totalBytes: totalSize, type: .delete, destination: nil)
        showPanel(progress: progress, itemCount: items.count, operation: "delete")
        defer { progress.complete() }
        for url in items {
            guard !progress.isCancelled else { break }
            await trashItem(url: url, progress: progress)
        }
        return progress
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
        let result = AppState.isAppManagedNetworkMountPath(url)
            ? await deleteAppManagedItem(url: url, progress: progress)
            : await Self.trashItemOffMainActor(url)
        switch result {
        case .success:
            guard !progress.isCancelled else { return }
            progress.fileCompleted(name: url.lastPathComponent, success: true)
            progress.add(bytes: itemSize)
        case .failure(let error):
            guard !progress.isCancelled else { return }
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

    private nonisolated static func trashItemOffMainActor(_ url: URL) async -> Result<Void, Error> {
        await Task.detached(priority: .userInitiated) {
            do {
                try FileManager.default.trashItem(at: url, resultingItemURL: nil)
                return .success(())
            } catch {
                return .failure(error)
            }
        }.value
    }
}
