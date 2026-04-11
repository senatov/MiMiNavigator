//
//  CntMenuCoord+ArchiveOps.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 30.03.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//  Description: Pack files into archive — shows ProgressPanel, runs ArchiveService,
//               handles errors with ErrorAlertService popup, refreshes panel after.

import AppKit
import FileModelKit
import Foundation

extension CntMenuCoord {

    // MARK: - Pack (Archive with options)
    /// Pack files into archive — shows ProgressPanel, supports cancel + rollback.
    func performPack(
        files: [CustomFile],
        archiveName: String,
        format: ArchiveFormat,
        destination: URL,
        deleteSource: Bool = false,
        compressionLevel: CompressionLevel = .normal,
        password: String? = nil,
        appState: AppState
    ) async {
        let fullName = "\(archiveName).\(format.fileExtension)"
        log.info("[Pack] \(#function) start — '\(fullName)' files=\(files.count) dest='\(destination.path)' level=\(compressionLevel) deleteSource=\(deleteSource) encrypted=\(password != nil)")
        isProcessing = true
        defer {
            isProcessing = false
            activeDialog = nil
        }
        let progressPanel = ProgressPanel.shared
        let handle = ActiveArchiveProcess()

        // show progress HUD
        await MainActor.run {
            progressPanel.showPacking(
                archiveName: fullName,
                destinationPath: destination.path,
                fileCount: files.count,
                cancelHandler: { [handle] in
                    log.info("[Pack] user cancelled — terminating process")
                    handle.terminate()
                }
            )
        }

        // run actual archive creation
        let sourceURLs = files.map(\.urlValue)
        do {
            let archiveURL = try await ArchiveService.shared.createArchive(
                from: sourceURLs,
                to: destination,
                archiveName: archiveName,
                format: format,
                compressionLevel: compressionLevel,
                password: password,
                onProgress: { line in
                    Task { @MainActor in
                        progressPanel.appendLog(line)
                    }
                },
                processHandle: handle
            )
            log.info("[Pack] done — '\(archiveURL.lastPathComponent)'")

            // delete source files if requested
            if deleteSource {
                for url in sourceURLs {
                    do {
                        try FileManager.default.trashItem(at: url, resultingItemURL: nil)
                        log.debug("[Pack] trashed source: \(url.lastPathComponent)")
                    } catch {
                        log.warning("[Pack] trash failed: \(url.lastPathComponent) — \(error.localizedDescription)")
                    }
                }
            }

            // hide progress & refresh both panels
            await MainActor.run {
                progressPanel.hide()
            }
            await refreshAfterArchiveOp(appState: appState, destination: destination)

        } catch is CancellationError {
            log.info("[Pack] cancelled by user")
            await MainActor.run { progressPanel.hide() }

        } catch {
            log.error("[Pack] FAILED — \(error.localizedDescription)")
            await MainActor.run {
                progressPanel.hide()
                ErrorAlertService.show(
                    title: "Archive creation failed",
                    message: "Could not create '\(fullName)'.\n\nReason: \(error.localizedDescription)",
                    style: .critical
                )
            }
        }
    }

    // MARK: - Refresh after archive op

    /// Refresh panels that show the destination or source directory
    private func refreshAfterArchiveOp(appState: AppState, destination: URL) async {
        let destPath = destination.path
        let leftPath = await MainActor.run { appState.path(for: .left) }
        let rightPath = await MainActor.run { appState.path(for: .right) }
        // refresh whichever panel(s) show the destination dir
        if leftPath == destPath {
            await appState.scanner.forceRefreshAfterFileOp(side: .left)
            log.debug("[Pack] refreshed left panel after pack")
        }
        if rightPath == destPath {
            await appState.scanner.forceRefreshAfterFileOp(side: .right)
            log.debug("[Pack] refreshed right panel after pack")
        }
    }
}
