// BatchOpsCoord+RemoteToRemote.swift
// MiMiNavigator
// Copyright © 2026 Senatov. All rights reserved.

import FileModelKit
import Foundation

// MARK: - Remote to Remote Transfer
extension BatchOpsCoord {
    // MARK: - Transfer Between Remote Directories
    @discardableResult
    func performRemoteToRemoteTransfer(
        files: [CustomFile],
        destination: URL,
        sourcePanel: FavPanelSide?,
        appState: AppState,
        moveSource: Bool = false,
        renameOnConflict: Bool = false
    ) async -> Bool {
        let operation: FileOperationOutcomePresenter.Operation = moveSource ? .move : .copy
        let manager = RemoteConnectionManager.shared
        guard let sourcePanel,
              let sourceConnection = manager.connection(for: appState.url(for: sourcePanel)),
              let destinationConnection = manager.connection(for: destination) else {
            FileOperationOutcomePresenter.failure(operation, message: "No active SFTP/FTP connection.")
            return false
        }
        let destinationPath = destination.path.isEmpty ? "/" : destination.path
        let sameServer = AppState.remoteOrigin(from: appState.url(for: sourcePanel).absoluteString)
            == AppState.remoteOrigin(from: destination.absoluteString)
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
            var targetPath = destinationPath == "/" ? "/\(file.nameStr)" : destinationPath + "/\(file.nameStr)"
            progress.updateStatus("[\(index + 1)/\(files.count)] \(file.nameStr)")
            do {
                let serverMove = moveSource && sameServer ? sourceConnection.provider as? SFTPFileProvider : nil
                var existingNames: Set<String> = []
                if renameOnConflict || serverMove != nil {
                    let existing = try await destinationConnection.provider.listDirectory(destinationPath)
                    existingNames = Set(existing.map(\.name))
                }
                if renameOnConflict {
                    let targetName = RemoteTransferNameResolver.uniqueName(file.nameStr, isDirectory: file.isDirectory, existingNames: existingNames)
                    targetPath = destinationPath == "/" ? "/\(targetName)" : destinationPath + "/\(targetName)"
                }
                guard !sameServer || file.pathStr != targetPath,
                      !sameServer || !file.isDirectory || !destinationPath.hasPrefix(file.pathStr + "/") else {
                    throw RemoteProviderError.downloadFailed("Destination is the source or inside the source directory")
                }
                var movedOnServer = false
                if let serverMove, !existingNames.contains((targetPath as NSString).lastPathComponent) {
                    do {
                        try await serverMove.moveItem(at: file.pathStr, to: targetPath)
                        movedOnServer = true
                    } catch {
                        log.warning("[BatchOps] server-side move unavailable; copying instead: \(error.localizedDescription)")
                    }
                }
                if !movedOnServer {
                    try await copyRemoteItem(file, to: targetPath, from: sourceConnection.provider, using: destinationConnection.provider)
                    if moveSource {
                        guard !progress.isCancelled else { break }
                        try await sourceConnection.provider.deleteItem(at: file.pathStr, recursive: file.isDirectory)
                    }
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
            let panelURL = appState.url(for: panel)
            if panelURL == destination || moveSource && panel == sourcePanel {
                await appState.refreshRemoteFiles(for: panel)
            }
        }
        return !progress.isCancelled && failed == 0 && succeeded == files.count
    }

    // MARK: - Stage One Remote Item
    private func copyRemoteItem(
        _ file: CustomFile,
        to targetPath: String,
        from source: any RemoteFileProvider,
        using destination: any RemoteFileProvider
    ) async throws {
        let stagingDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("mimi-remote-transfer-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: stagingDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: stagingDirectory) }
        let stagedItem = stagingDirectory.appendingPathComponent(file.nameStr, isDirectory: file.isDirectory)
        try await source.downloadToLocal(remotePath: file.pathStr, localPath: stagedItem.path, recursive: file.isDirectory)
        try await destination.uploadToRemote(localPath: stagedItem.path, remotePath: targetPath, recursive: file.isDirectory)
    }
}
