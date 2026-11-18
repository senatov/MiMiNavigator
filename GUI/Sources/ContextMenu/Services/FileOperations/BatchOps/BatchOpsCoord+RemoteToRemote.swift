// BatchOpsCoord+RemoteToRemote.swift
// MiMiNavigator
// Copyright © 2026 Senatov. All rights reserved.

import FileModelKit
import Foundation

// MARK: - Remote to Remote Transfer
extension BatchOpsCoord {
    // MARK: - Transfer Between Remote Directories
    func performRemoteToRemoteTransfer(
        files: [CustomFile],
        destination: URL,
        sourcePanel: FavPanelSide?,
        appState: AppState,
        moveSource: Bool = false
    ) async {
        let operation: FileOperationOutcomePresenter.Operation = moveSource ? .move : .copy
        guard let connection = RemoteConnectionManager.shared.connection(for: destination) else {
            FileOperationOutcomePresenter.failure(operation, message: "No active SFTP/FTP connection.")
            return
        }
        let origin = AppState.remoteOrigin(from: connection.provider.mountPath)
        guard AppState.remoteOrigin(from: destination.absoluteString) == origin,
              sourcePanel.map({ AppState.remoteOrigin(from: appState.url(for: $0).absoluteString) == origin }) ?? true else {
            FileOperationOutcomePresenter.failure(operation, message: "The source and destination must use the active remote connection.")
            return
        }
        let destinationPath = destination.path.isEmpty ? "/" : destination.path
        let progress = ProgressPanel.shared
        progress.showFileOp(
            icon: moveSource ? "arrow.right.doc.fill" : "doc.on.doc.fill",
            title: "\(moveSource ? "Moving" : "Copying") \(files.count) remote item(s)",
            itemCount: files.count,
            destination: destinationPath
        )
        progress.updateProgress(nil)
        var succeeded = 0
        var failed = 0
        var firstFailure: String?
        for (index, file) in files.enumerated() {
            guard !progress.isCancelled else {
                progress.appendLog("⛔ Cancelled")
                break
            }
            let targetPath = destinationPath == "/" ? "/\(file.nameStr)" : destinationPath + "/\(file.nameStr)"
            progress.updateStatus("[\(index + 1)/\(files.count)] \(file.nameStr)")
            do {
                guard file.pathStr != targetPath,
                      !file.isDirectory || !destinationPath.hasPrefix(file.pathStr + "/") else {
                    throw RemoteProviderError.downloadFailed("Destination is the source or inside the source directory")
                }
                try await copyRemoteItem(file, to: targetPath, using: connection.provider)
                if moveSource {
                    try await connection.provider.deleteItem(at: file.pathStr, recursive: file.isDirectory)
                }
                succeeded += 1
                progress.appendLog("\(moveSource ? "➡" : "📄") \(file.nameStr)")
                log.info("[BatchOps] remote \(moveSource ? "move" : "copy") '\(file.pathStr)' → '\(targetPath)'")
            } catch {
                failed += 1
                let message = humanReadableRemoteErrorMessage(error, operation: moveSource ? "move" : "copy", targetPath: targetPath)
                firstFailure = firstFailure ?? message
                progress.appendLog("❌ \(file.nameStr): \(error.localizedDescription)")
                log.error("[BatchOps] remote transfer '\(file.pathStr)' → '\(targetPath)' failed: \(error.localizedDescription)")
            }
            progress.updateProgress(Double(succeeded + failed) / Double(files.count))
        }
        if progress.isCancelled {
            progress.finish(success: false, message: "⏹ Cancelled — \(succeeded) completed")
            FileOperationOutcomePresenter.cancelled(operation)
        } else if failed > 0 {
            progress.finish(success: false, message: "⚠️ \(succeeded) completed, \(failed) failed")
            FileOperationOutcomePresenter.failure(operation, message: firstFailure ?? "Remote transfer failed")
        } else {
            progress.finish(success: true, message: "✅ \(succeeded) item(s) transferred")
            FileOperationOutcomePresenter.success(operation, itemCount: succeeded)
        }
        for panel in [FavPanelSide.left, .right] where appState.isRemotePanel(panel) {
            let panelPath = appState.url(for: panel).path
            if panelPath == destinationPath || moveSource && panel == sourcePanel {
                await appState.refreshRemoteFiles(for: panel)
            }
        }
    }

    // MARK: - Stage One Remote Item
    private func copyRemoteItem(_ file: CustomFile, to targetPath: String, using provider: any RemoteFileProvider) async throws {
        let stagingDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("mimi-remote-transfer-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: stagingDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: stagingDirectory) }
        let stagedItem = stagingDirectory.appendingPathComponent(file.nameStr, isDirectory: file.isDirectory)
        try await provider.downloadToLocal(remotePath: file.pathStr, localPath: stagedItem.path, recursive: file.isDirectory)
        try await provider.uploadToRemote(localPath: stagedItem.path, remotePath: targetPath, recursive: file.isDirectory)
    }
}
