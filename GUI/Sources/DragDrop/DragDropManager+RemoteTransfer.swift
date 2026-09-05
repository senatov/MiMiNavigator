// DragDropManager+RemoteTransfer.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Remote upload and safe staged download support for drag-and-drop.

import FileModelKit
import Foundation

// MARK: - Remote Transfers
extension DragDropManager {
    // MARK: - Remote Upload
    func performRemoteUpload(
        _ kind: FileTransferAction,
        operation: FileTransferOperation,
        appState: AppState
    ) async {
        guard kind != .abort else { return }
        guard let connection = RemoteConnectionManager.shared.activeConnection else {
            log.error("[DnD] remote upload — no active connection")
            return
        }
        let provider = connection.provider
        let destination = operation.destinationPath
        let files = operation.sourceFiles
        let panel = ProgressPanel.shared
        panel.showFileOp(
            icon: "arrow.up.doc.fill",
            title: operationTitle(prefix: "⬆ Uploading", files: files),
            itemCount: files.count,
            destination: normalizedRemoteDestinationPath(destination)
        )
        var succeeded = 0
        var failed = 0
        for (index, file) in files.enumerated() {
            guard !panel.isCancelled else {
                panel.appendLog("⛔ Cancelled")
                break
            }
            let remotePath = remoteDestinationPath(for: file, in: destination)
            let isDirectory = file.isDirectory || file.isSymbolicDirectory
            panel.updateStatus("[\(index + 1)/\(files.count)] \(file.nameStr)")
            do {
                try await provider.uploadToRemote(
                    localPath: file.urlValue.path,
                    remotePath: remotePath,
                    recursive: isDirectory
                )
                if kind == .move {
                    try await moveLocalItemToTrash(file.urlValue)
                }
                panel.appendLog(isDirectory ? "📁 \(file.nameStr)/" : "📄 \(file.nameStr)")
                log.info("[DnD] uploaded '\(file.nameStr)' → '\(destinationDisplayName(destination))'")
                succeeded += 1
            } catch {
                let message = humanReadableRemoteUploadError(error, targetPath: remotePath)
                log.error("[DnD] upload '\(file.nameStr)' failed: \(error.localizedDescription)")
                panel.appendLog("❌ \(file.nameStr): \(message)")
                failed += 1
            }
        }
        finishRemoteProgress(panel, succeeded: succeeded, failed: failed, total: files.count, verb: "uploaded")
        await refreshAffectedPanels(appState: appState, operation: operation)
    }

    // MARK: - Remote Download
    func performRemoteDownload(
        operation: FileTransferOperation,
        appState: AppState
    ) async {
        guard let connection = RemoteConnectionManager.shared.activeConnection else {
            log.error("[DnD] remote download — no active connection")
            return
        }
        let destination = operation.destinationPath
        let provider = connection.provider
        let panel = ProgressPanel.shared
        let files = operation.sourceFiles
        panel.showFileOp(
            icon: "arrow.down.doc.fill",
            title: operationTitle(prefix: "⬇ Downloading", files: files),
            itemCount: files.count,
            destination: destination.path
        )
        var succeeded = 0
        var failed = 0
        for (index, file) in files.enumerated() {
            guard !panel.isCancelled else {
                panel.appendLog("⛔ Cancelled")
                break
            }
            let finalURL = destination.appendingPathComponent(file.nameStr)
            let stagingURL = stagingDownloadURL(for: finalURL)
            panel.updateStatus("[\(index + 1)/\(files.count)] \(file.nameStr)")
            do {
                if file.isDirectory {
                    try await provider.downloadToLocal(
                        remotePath: file.urlValue.path,
                        localPath: stagingURL.path,
                        recursive: true
                    )
                } else {
                    let temporaryURL = try await provider.downloadFile(remotePath: file.urlValue.path)
                    try FileManager.default.moveItem(at: temporaryURL, to: stagingURL)
                }
                try installStagedDownload(at: stagingURL, to: finalURL)
                panel.appendLog(downloadLogLine(for: file, at: finalURL))
                log.info("[DnD] downloaded '\(file.nameStr)' → '\(destination.lastPathComponent)'")
                succeeded += 1
            } catch {
                try? FileManager.default.removeItem(at: stagingURL)
                log.error("[DnD] download '\(file.nameStr)' failed: \(error.localizedDescription)")
                panel.appendLog("❌ \(file.nameStr): \(error.localizedDescription)")
                failed += 1
            }
        }
        finishRemoteProgress(panel, succeeded: succeeded, failed: failed, total: files.count, verb: "downloaded")
        await refreshAffectedPanels(appState: appState, operation: operation)
    }

    private func operationTitle(prefix: String, files: [CustomFile]) -> String {
        let totalSize = files.reduce(Int64(0)) { $0 + $1.sizeInBytes }
        let size = ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
        return "\(prefix) \(files.count) item(s) — \(size)"
    }

    private func normalizedRemoteDestinationPath(_ destination: URL) -> String {
        destination.path.isEmpty ? "/" : destination.path
    }

    func destinationDisplayName(_ destination: URL) -> String {
        let normalizedPath = normalizedRemoteDestinationPath(destination)
        if normalizedPath == "/" { return "/" }
        return destination.lastPathComponent.isEmpty ? normalizedPath : destination.lastPathComponent
    }

    private func remoteDestinationPath(for file: CustomFile, in destination: URL) -> String {
        let destinationPath = normalizedRemoteDestinationPath(destination)
        return destinationPath == "/" ? "/\(file.nameStr)" : destinationPath + "/\(file.nameStr)"
    }

    private func humanReadableRemoteUploadError(_ error: Error, targetPath: String) -> String {
        let message = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = message.lowercased()
        if lowercased.contains("permission") || lowercased.contains("access denied") {
            return "Server denied upload to '\(targetPath)'. Check write permissions for that remote folder."
        }
        if lowercased.contains("citadel.sftpmessage.status error 1") {
            return "Server rejected upload to '\(targetPath)'. This usually means the folder is read-only or does not allow file creation."
        }
        return message
    }

    private func moveLocalItemToTrash(_ url: URL) async throws {
        _ = try await FileRecycleService.recycle(url)
    }

    private func stagingDownloadURL(for finalURL: URL) -> URL {
        finalURL.deletingLastPathComponent()
            .appendingPathComponent(".mimi-download-\(UUID().uuidString)", isDirectory: false)
    }

    private func installStagedDownload(at stagingURL: URL, to finalURL: URL) throws {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: finalURL.path) else {
            try fileManager.moveItem(at: stagingURL, to: finalURL)
            return
        }
        let backupURL = finalURL.deletingLastPathComponent()
            .appendingPathComponent(".mimi-backup-\(UUID().uuidString)", isDirectory: false)
        try fileManager.moveItem(at: finalURL, to: backupURL)
        do {
            try fileManager.moveItem(at: stagingURL, to: finalURL)
            try fileManager.removeItem(at: backupURL)
        } catch {
            if fileManager.fileExists(atPath: finalURL.path) {
                try? fileManager.removeItem(at: finalURL)
            }
            try? fileManager.moveItem(at: backupURL, to: finalURL)
            throw error
        }
    }

    private func downloadLogLine(for file: CustomFile, at finalURL: URL) -> String {
        if file.isDirectory { return "📁 \(file.nameStr)/" }
        let attributes = try? FileManager.default.attributesOfItem(atPath: finalURL.path)
        let byteCount = attributes?[.size] as? Int64 ?? 0
        let size = ByteCountFormatter.string(fromByteCount: byteCount, countStyle: .file)
        return "📄 \(file.nameStr) (\(size))"
    }

    private func finishRemoteProgress(
        _ panel: ProgressPanel,
        succeeded: Int,
        failed: Int,
        total: Int,
        verb: String
    ) {
        if panel.isCancelled {
            panel.finish(success: false, message: "⏹ Cancelled — \(succeeded)/\(total)")
        } else if failed > 0 {
            panel.finish(success: false, message: "⚠️ \(succeeded) ok, \(failed) failed")
        } else {
            panel.finish(success: true, message: "✅ \(succeeded) item(s) \(verb)")
        }
    }
}
