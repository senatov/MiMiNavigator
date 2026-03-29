//
//  BatchOperationCoordinator+RemoteTransfer.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 29.03.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import FileModelKit
import Foundation

@MainActor
private enum BatchOpsCoordRemoteState {
    static var cancelledDownload = false
    static var cancelledUpload = false
}

extension BatchOpsCoord {

    // MARK: - Remote transfer state

    var cancelledDownload: Bool {
        get { BatchOpsCoordRemoteState.cancelledDownload }
        set { BatchOpsCoordRemoteState.cancelledDownload = newValue }
    }

    var cancelledUpload: Bool {
        get { BatchOpsCoordRemoteState.cancelledUpload }
        set { BatchOpsCoordRemoteState.cancelledUpload = newValue }
    }

    // MARK: - Human-readable remote errors

    func humanReadableRemoteErrorMessage(_ error: Error, operation: String, targetPath: String) -> String {
        let message = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = message.lowercased()

        if lowercased.contains("not connected") {
            return "There is no active connection to the remote server. Reconnect and try again."
        }

        if lowercased.contains("permission") || lowercased.contains("access denied") {
            return "The server did not allow \(operation) to '\(targetPath)'. Check permissions on the remote side."
        }

        if lowercased.contains("no such file") || lowercased.contains("not found") {
            return "The remote path '\(targetPath)' was not found. The directory may have been removed or the path may be incorrect."
        }

        if lowercased.contains("timed out") || lowercased.contains("couldn't connect") || lowercased.contains("failed to connect") {
            return "Could not reach the remote server. Check the network connection and try again."
        }

        if lowercased.contains("citadel.sftpmessage.status error 1") {
            return "The server rejected \(operation) for '\(targetPath)'. This usually means write permission is missing or writing to that directory is not allowed."
        }

        return "Could not complete \(operation) for '\(targetPath)'.\n\nTechnical reason: \(message)"
    }

    func showRemoteOperationError(title: String, error: Error, operation: String, targetPath: String) {
        let message = humanReadableRemoteErrorMessage(error, operation: operation, targetPath: targetPath)
        ErrorAlertService.show(
            title: title,
            message: message,
            style: .warning
        )
    }

    // MARK: - Remote download

    func performRemoteDownload(
        files: [CustomFile],
        sourcePanel: FavPanelSide,
        destination: URL,
        appState: AppState
    ) async {
        let manager = RemoteConnectionManager.shared
        guard let conn = manager.activeConnection else {
            log.error("[BatchOps] remote download — no active connection")
            ErrorAlertService.show(
                title: "Not Connected",
                message: "No active SFTP/FTP connection.",
                style: .warning
            )
            return
        }

        let totalItems = files.count
        let totalSize = files.reduce(Int64(0)) { $0 + $1.sizeInBytes }
        let sizeText = ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)

        cancelledDownload = false

        let panel = ProgressPanel.shared
        panel.showFileOp(
            icon: "arrow.down.doc.fill",
            title: "⬇ Downloading \(totalItems) item(s) — \(sizeText)",
            itemCount: totalItems,
            destination: destination.lastPathComponent,
            cancelHandler: { [weak self] in self?.cancelledDownload = true }
        )

        var ok = 0
        var fail = 0
        var firstErrorMessage: String?
        var firstErrorTitle: String?

        for (index, file) in files.enumerated() {
            if cancelledDownload {
                panel.appendLog("⛔ Cancelled by user")
                break
            }

            let remotePath = file.pathStr
            panel.updateStatus("[\(index + 1)/\(totalItems)] \(file.nameStr)")

            do {
                try await conn.provider.downloadToLocal(
                    remotePath: remotePath,
                    localPath: destination.path,
                    recursive: file.isDirectory
                )
                log.info("[BatchOps] downloaded '\(file.nameStr)' → '\(destination.lastPathComponent)'")
                panel.appendLog("⬇ \(file.nameStr)")
                ok += 1
            } catch {
                let errorMessage = error.localizedDescription
                log.error("[BatchOps] download '\(file.nameStr)' failed: \(errorMessage)")
                panel.appendLog("❌ \(file.nameStr): \(errorMessage)")
                if firstErrorMessage == nil {
                    firstErrorTitle = "Remote Download Error"
                    firstErrorMessage = humanReadableRemoteErrorMessage(
                        error,
                        operation: "download",
                        targetPath: remotePath
                    )
                }
                fail += 1
            }
        }

        if cancelledDownload {
            panel.finish(success: false, message: "⏹ Cancelled — \(ok) downloaded, \(fail) failed")
        } else if fail > 0 {
            panel.finish(success: false, message: "⚠️ \(ok) downloaded, \(fail) failed")
        } else {
            panel.finish(success: true, message: "✅ \(ok) item(s) downloaded")
        }

        if fail > 0,
           let firstErrorTitle,
           let firstErrorMessage {
            ErrorAlertService.show(
                title: firstErrorTitle,
                message: firstErrorMessage,
                style: .warning
            )
        }

        await appState.refreshFiles(for: sourcePanel == .left ? .right : .left, force: true)
    }

    // MARK: - Remote upload

    func performRemoteUpload(
        files: [CustomFile],
        sourcePanel: FavPanelSide,
        destinationPanel: FavPanelSide,
        appState: AppState
    ) async {
        let manager = RemoteConnectionManager.shared
        guard let conn = manager.activeConnection else {
            log.error("[BatchOps] remote upload — no active connection")
            ErrorAlertService.show(
                title: "Not Connected",
                message: "No active SFTP/FTP connection.",
                style: .warning
            )
            return
        }

        let destinationURL = appState.url(for: destinationPanel)
        let destinationPath = destinationURL.path.isEmpty ? "/" : destinationURL.path
        let totalItems = files.count
        let totalSize = files.reduce(Int64(0)) { $0 + $1.sizeInBytes }
        let sizeText = ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)

        cancelledUpload = false

        let panel = ProgressPanel.shared
        panel.showFileOp(
            icon: "arrow.up.doc.fill",
            title: "⬆ Uploading \(totalItems) item(s) — \(sizeText)",
            itemCount: totalItems,
            destination: destinationPath,
            cancelHandler: { [weak self] in self?.cancelledUpload = true }
        )

        var ok = 0
        var fail = 0
        var firstErrorMessage: String?
        var firstErrorTitle: String?

        for (index, file) in files.enumerated() {
            if cancelledUpload {
                panel.appendLog("⛔ Cancelled by user")
                break
            }

            let sourceURL = file.urlValue
            let targetPath = destinationPath == "/"
                ? "/\(file.nameStr)"
                : destinationPath + "/\(file.nameStr)"

            panel.updateStatus("[\(index + 1)/\(totalItems)] \(file.nameStr)")

            do {
                try await conn.provider.uploadToRemote(
                    localPath: sourceURL.path,
                    remotePath: targetPath,
                    recursive: file.isDirectory
                )
                panel.appendLog("⬆ \(file.nameStr)")
                log.info("[BatchOps] uploaded '\(file.nameStr)' → '\(targetPath)'")
                ok += 1
            } catch {
                let errorMessage = error.localizedDescription
                panel.appendLog("❌ \(file.nameStr): \(errorMessage)")
                log.error("[BatchOps] upload '\(file.nameStr)' failed: \(errorMessage)")
                if firstErrorMessage == nil {
                    firstErrorTitle = "Remote Upload Error"
                    firstErrorMessage = humanReadableRemoteErrorMessage(
                        error,
                        operation: "upload",
                        targetPath: targetPath
                    )
                }
                fail += 1
            }
        }

        log.info("[BatchOps] remote upload done: ok=\(ok) fail=\(fail)")

        if cancelledUpload {
            panel.finish(success: false, message: "⏹ Cancelled — \(ok) uploaded, \(fail) failed")
        } else if fail > 0 {
            panel.finish(success: false, message: "⚠️ \(ok) uploaded, \(fail) failed")
        } else {
            panel.finish(success: true, message: "✅ \(ok) item(s) uploaded")
        }

        if fail > 0,
           let firstErrorTitle,
           let firstErrorMessage {
            ErrorAlertService.show(
                title: firstErrorTitle,
                message: firstErrorMessage,
                style: .warning
            )
        }

        await appState.refreshRemoteFiles(for: destinationPanel)
        await appState.refreshFiles(for: sourcePanel, force: true)
    }
}
