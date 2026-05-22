// FileOpsEngine+Delete.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 14.05.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Delete implementation.

import Foundation

// MARK: - Delete Implementation

extension FileOpsEngine {

    private struct RecursiveDeletePlan: Sendable {
        let files: [URL]
        let directories: [URL]
        var totalCount: Int { files.count + directories.count }
    }

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
        progress.appendStep("Preparing delete: \(url.lastPathComponent)")
        let isDirectory = isDirectory(url: url)
        guard isDirectory else {
            progress.appendStep("Deleting file: \(url.lastPathComponent)")
            return await Self.removeItemOffMainActor(url)
        }
        progress.appendStep("Scanning directory contents: \(url.lastPathComponent)")
        let planResult = await Self.makeRecursiveDeletePlan(root: url)
        switch planResult {
        case .failure(let error):
            return .failure(error)
        case .success(let plan):
            progress.appendStep("Found \(plan.files.count) file(s), \(max(0, plan.directories.count - 1)) subfolder(s)")
            let total = max(1, plan.totalCount)
            var done = 0
            for fileURL in plan.files {
                guard !progress.isCancelled else { return .failure(CocoaError(.userCancelled)) }
                done += 1
                ProgressPanel.shared.updateStatus("[\(done)/\(total)] Deleting file: \(fileURL.lastPathComponent)")
                ProgressPanel.shared.updateProgress(Double(done) / Double(total))
                let result = await Self.removeItemOffMainActor(fileURL)
                if case .failure(let error) = result {
                    return .failure(error)
                }
                ProgressPanel.shared.appendLog("Deleted file: \(fileURL.lastPathComponent)")
            }
            for directoryURL in plan.directories {
                guard !progress.isCancelled else { return .failure(CocoaError(.userCancelled)) }
                done += 1
                ProgressPanel.shared.updateStatus("[\(done)/\(total)] Deleting folder: \(directoryURL.lastPathComponent)")
                ProgressPanel.shared.updateProgress(Double(done) / Double(total))
                let result = await Self.removeItemOffMainActor(directoryURL)
                if case .failure(let error) = result {
                    return .failure(error)
                }
                ProgressPanel.shared.appendLog("Deleted folder: \(directoryURL.lastPathComponent)")
            }
            return .success(())
        }
    }

    private nonisolated static func makeRecursiveDeletePlan(root: URL) async -> Result<RecursiveDeletePlan, Error> {
        await Task.detached(priority: .userInitiated) {
            let fileManager = FileManager.default
            let keys: [URLResourceKey] = [.isDirectoryKey, .isSymbolicLinkKey]
            guard let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: keys,
                options: []
            ) else {
                return .failure(CocoaError(.fileReadUnknown))
            }
            var files: [URL] = []
            var directories: [URL] = []
            while let itemURL = enumerator.nextObject() as? URL {
                let values = try? itemURL.resourceValues(forKeys: Set(keys))
                let isDirectory = values?.isDirectory == true && values?.isSymbolicLink != true
                if isDirectory {
                    directories.append(itemURL)
                } else {
                    files.append(itemURL)
                }
            }
            directories.sort {
                $0.pathComponents.count > $1.pathComponents.count
            }
            directories.append(root)
            return .success(RecursiveDeletePlan(files: files, directories: directories))
        }.value
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
